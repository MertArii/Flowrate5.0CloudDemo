"""Sentetik örnek veri setini (JSON dosya, düz liste) tickets tablosuna yazan
admin/demo endpoint'i.

AMAÇ: Bu ticket'larda 'answer'/cozum metni YOK — bilerek. Hedef RAG bilgi
bankasını (ticket_solutions) beslemek değil, get_agents_by_category()'nin
geçmiş-kayıt fallback'ini (tickets.extracted_category + assigned_agent_id)
DOĞRU örneklerle beslemek. Böylece gerçek bir soru geldiğinde ("/ask"),
router.py bu kategoriyi kimin çözdüğünü bu sentetik geçmişten öğrenip
doğru uzmana yönlendirebilir.

Beklenen dosya biçimi — DÜZ LİSTE, her eleman bir ticket, alanlar TAMAMEN
DÜZ (nested obje yok):

[
  {
    "customer_email": "emin@sirket.com",
    "recipient_email": "btdestek@sirket.com",
    "subject": "Excel Büyük Dosyalarda Kilitleniyor",
    "raw_issue_description": "Maliyet hesaplamaları yaptığım makrolu Excel...",
    "extracted_category": "IT-Donanim",
    "region": "İstanbul",
    "status": "new",
    "priority": "medium",
    "assigned_group_name": "BT Destek Ekibi",
    "assigned_agent_email": "emirhan.teknoloji@sirket.com",
    "alt_kategori_adi": "Ofis Uygulamaları",
    "sap_module_code": null,
    "sla_level": 3,
    "ozet": "..."
  },
  ...
]

Bilinçli olarak kullanılmayan alan: "ozet" — tickets tablosunda karşılığı
yok, sessizce atlanır.

"sla_level" (1..5) SADECE "priority" alanı hiç gelmediyse fallback olarak
kullanılır (_ONCELIK_MAP ile priority string'ine çevrilir). "priority"
geldiyse doğrudan o kullanılır, sla_level'a bakılmaz.

BİLİNEN KISIT: "alt_kategori_adi" tek başına geliyor, kategori_grubu YOK.
store.get_alt_kategori_id() ikisini birden istiyor (JOIN ile eşleştiriyor),
bu yüzden bu veri setiyle sub_category_id şu an HİÇBİR ZAMAN eşleşmeyecek —
her ticket için uyarı düşecek. Kalıcı çözüm için store.py'ye isimle tek
başına arayan bir fonksiyon eklenmesi gerekiyor (bkz. modül sonu TODO).

assigned_agent_email / assigned_group_name DB'de bulunamazsa ticket YİNE DE
eklenir (ilgili id NULL kalır) — tek bir eşleşmeme tüm batch'i durdurmaz,
"uyarilar" içinde raporlanır.
"""
from __future__ import annotations

import json
import logging

from fastapi import APIRouter, File, Header, HTTPException, UploadFile

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])

# sla_level ("1".."5") ile tickets.priority kolonunun beklediği string
# etiket arasındaki eşleme — import_sla_dataset.py'deki _ONCELIK_MAP ile
# AYNI olmalı. Sadece "priority" alanı verilmediyse fallback olarak kullanılır.
_ONCELIK_MAP = {1: "urgent", 2: "high", 3: "medium", 4: "low", 5: "planned"}

_VARSAYILAN_MUSTERI_EMAIL = "sentetik.veri@sirket.com"
_VARSAYILAN_ALICI_EMAIL = "destek@sirket.com"
_VARSAYILAN_STATUS = "resolved"


def _sla_level_to_priority(sla_level) -> str:
    try:
        n = int(str(sla_level).split(".")[0])
    except (TypeError, ValueError):
        n = 3
    return _ONCELIK_MAP.get(n, "medium")


async def _import_one(store, ticket: dict) -> list[str]:
    """Tek bir ticket objesini gerçek store API'siyle ekler. Uyarı listesini döner."""
    uyarilar: list[str] = []

    modul = ticket.get("extracted_category") or "Diger"

    priority = ticket.get("priority")
    if not priority:
        priority = _sla_level_to_priority(ticket.get("sla_level", "3"))

    # sub_category_id: alt_kategori_adi + kategori_grubu isminden çözülür.
    # BİLİNEN KISIT: bu veri setinde kategori_grubu yok, bu yüzden lookup
    # şu an hep None dönecek (bkz. modül başındaki not).
    alt_kategori = ticket.get("alt_kategori_adi")
    kategori_grubu = ticket.get("kategori_grubu_adi")  # bu alan veri setinde yok
    sub_category_id = None
    if alt_kategori:
        if kategori_grubu:
            sub_category_id = store.get_alt_kategori_id(alt_kategori, kategori_grubu)
            if not sub_category_id:
                uyarilar.append(
                    f"alt_kategori_adi='{alt_kategori}' / kategori_grubu_adi='{kategori_grubu}' eşleşmedi."
                )
        else:
            uyarilar.append(
                f"alt_kategori_adi='{alt_kategori}' verildi ama kategori_grubu_adi yok, "
                "sub_category_id eşleştirilemedi (store.get_alt_kategori_id ikisini de istiyor)."
            )

    # sap_module_id: sap_module_code'dan çözülür
    sap_module_id = None
    sap_module_code = ticket.get("sap_module_code")
    if sap_module_code:
        sap_module_id = store.get_sap_module_id(sap_module_code)
        if not sap_module_id:
            uyarilar.append(f"sap_module_code='{sap_module_code}' eşleşmedi.")

    # assigned_group_id: assigned_group_name'den bulunur (yoksa oluşturulmaz —
    # sadece var olan gerçek ekip kullanılmalı, hayali ekip icat edilmesin)
    group_id = None
    ekip = ticket.get("assigned_group_name")
    if ekip:
        group_id = store.get_support_group_id_by_name(ekip)
        if not group_id:
            uyarilar.append(f"assigned_group_name='{ekip}' support_groups'ta bulunamadı.")

    # assigned_agent_id: assigned_agent_email'den bulunur — BU EN ÖNEMLİ ALAN,
    # çünkü get_agents_by_category() fallback'i tam olarak bunu okuyor.
    agent_id = None
    atanan_uzman = ticket.get("assigned_agent_email")
    if atanan_uzman:
        agent_id = store.get_user_id_by_email(atanan_uzman)
        if not agent_id:
            uyarilar.append(f"assigned_agent_email='{atanan_uzman}' users'ta bulunamadı, assigned_agent_id boş kaldı.")
        elif not group_id:
            # ekip verilmediyse ya da bulunamadıysa, agent'ın GERÇEK grubunu kullan.
            group_id = store.get_user_support_group_id(agent_id)

    # sla_policy_id: store.create_ticket() hazır bir UUID bekliyor, kendisi
    # lookup yapmıyor. Gerçek id, `priority` string'i ('urgent'|'high'|
    # 'medium'|'low'|'planned') üzerinden store.get_sla_policy() ile bulunur
    # (bkz. store.py:491, sla_policies.priority_key koluna göre).
    sla_policy_id = None
    sla = store.get_sla_policy(priority)
    if sla:
        sla_policy_id = sla["id"]
    else:
        uyarilar.append(f"priority='{priority}' için sla_policies eşleşmedi, sla_policy_id boş kaldı.")

    tid, tno = store.create_ticket(
        customer_email=ticket.get("customer_email", _VARSAYILAN_MUSTERI_EMAIL),
        recipient_email=ticket.get("recipient_email", _VARSAYILAN_ALICI_EMAIL),
        subject=(ticket.get("subject") or "")[:255],
        raw_issue_description=ticket.get("raw_issue_description", ""),
        extracted_category=modul,
        region=ticket.get("region"),
        status=ticket.get("status") or _VARSAYILAN_STATUS,
        priority=priority,
        assigned_group_id=group_id,
        assigned_agent_id=agent_id,
        sla_policy_id=sla_policy_id,
        response_deadline=None,
        workaround_deadline=None,
        resolution_deadline=None,
        sub_category_id=sub_category_id,
        sap_module_id=sap_module_id,
    )

    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"kaynak": "postman_seed_sentetik", "ticket": ticket},
        assigned_group_id=group_id,
        assigned_agent_id=agent_id,
        confidence_score=ticket.get("guven", 1.0),
    )

    return uyarilar


@router.post("/seed")
async def seed(
    file: UploadFile = File(...),
    x_admin_key: str | None = Header(default=None),
):
    """Sentetik örnek ticket'ları (düz JSON liste) tickets tablosuna yazar.

    Amaç: get_agents_by_category() geçmiş-kayıt fallback'ini doğru
    extracted_category + assigned_agent_id örnekleriyle beslemek."""
    admin_key = getattr(settings, "admin_seed_key", None)
    if admin_key and x_admin_key != admin_key:
        raise HTTPException(status_code=403, detail="Geçersiz admin anahtarı.")

    raw = await file.read()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=400, detail=f"Geçersiz JSON: {e}")

    if not isinstance(payload, list):
        raise HTTPException(
            status_code=400,
            detail="Dosya bir liste olmalı: [ {ticket1}, {ticket2}, ... ]",
        )

    from app.rag import store  # geç import

    store.open_pool()
    try:
        eklenen = 0
        basarisiz = 0
        tum_uyarilar: dict[int, list[str]] = {}

        for i, ticket in enumerate(payload):
            if not isinstance(ticket, dict):
                tum_uyarilar[i] = ["Liste elemanı bir obje değil, atlandı."]
                basarisiz += 1
                continue
            try:
                uyarilar = await _import_one(store, ticket)
                if uyarilar:
                    tum_uyarilar[i] = uyarilar
                eklenen += 1
            except Exception as e:
                basarisiz += 1
                tum_uyarilar[i] = [f"Eklenemedi: {e}"]
                logger.warning("seed(): ticket[%d] eklenemedi: %s", i, e)
    finally:
        store.close_pool()

    return {
        "eklenen": eklenen,
        "basarisiz": basarisiz,
        "toplam": len(payload),
        "uyarilar": tum_uyarilar,
    }


# TODO: alt_kategori_adi tek başına gelirse kesin eşleşme sağlamak için
# store.py'ye şuna benzer bir fonksiyon eklenmesi önerilir:
#
# def get_alt_kategori_id_by_name(name: str) -> str | None:
#     """Sadece alt kategori adına göre arar. Birden fazla grupta aynı isim
#     varsa ilk bulduğunu döner — isim çakışması varsa çağıran taraf
#     kategori_grubu_adi ile birlikte get_alt_kategori_id()'yi kullanmalı."""
#     if not name:
#         return None
#     with _connect() as conn, conn.cursor() as cur:
#         cur.execute("SELECT id FROM alt_kategoriler WHERE name = %s LIMIT 1", (name,))
#         row = cur.fetchone()
#         return str(row[0]) if row else None