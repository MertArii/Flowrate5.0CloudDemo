"""Sentetik örnek veri setini (JSON dosya, düz liste) tickets tablosuna yazan
admin/demo endpoint'i.

AMAÇ: Bu ticket'larda 'answer'/cozum metni YOK — bilerek. Hedef RAG bilgi
bankasını (ticket_solutions) beslemek değil, get_agents_by_category()'nin
geçmiş-kayıt fallback'ini (tickets.extracted_category + assigned_agent_id)
DOĞRU örneklerle beslemek. Böylece gerçek bir soru geldiğinde ("/ask"),
router.py bu kategoriyi kimin çözdüğünü bu sentetik geçmişten öğrenip
doğru uzmana yönlendirebilir.

Beklenen dosya biçimi — DÜZ LİSTE, her eleman bir ticket:

[
  {
    "subject": "Outlook Sürekli Kapanıyor",
    "content": "Maillerime bakarken Outlook uygulaması...",
    "siniflandirma": {
      "modul": "IT-Donanim",
      "oncelik": "3",
      "kategori_grubu": "Yazılım Arızaları",
      "alt_kategori": "Outlook",
      "sap_modulu": null
    },
    "yonlendirme": {
      "ekip": "BT Destek Ekibi",
      "atanan_uzman": "emirhan.teknoloji@sirket.com"
    }
  },
  ...
]

Bilinçli olarak kullanılmayan alanlar (siniflandirma.istek_turu,
siniflandirma.ust_kategori, siniflandirma.ozet, yonlendirme.ekip_gorunum_adi):
tickets tablosunda karşılığı yok / bu endpoint'in amacına (routing geçmişi)
katkısı yok, sessizce atlanır.

atanan_uzman DB'de bulunamazsa ticket YİNE DE eklenir (assigned_agent_id
NULL kalır) — tek bir eşleşmeme tüm batch'i durdurmaz, "uyarilar" içinde
raporlanır.
"""
from __future__ import annotations

import json
import logging

from fastapi import APIRouter, File, Header, HTTPException, UploadFile

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["admin"])

# classifier'ın "oncelik" alanı ("1".."5") ile tickets.priority kolonunun
# beklediği string etiket arasındaki eşleme — import_sla_dataset.py'deki
# _ONCELIK_MAP ile AYNI olmalı (tickets.priority ham "1".."5" kabul etmiyor).
_ONCELIK_MAP = {1: "urgent", 2: "high", 3: "medium", 4: "low", 5: "planned"}

_VARSAYILAN_MUSTERI_EMAIL = "sentetik.veri@sirket.com"
_VARSAYILAN_ALICI_EMAIL = "destek@sirket.com"


def _oncelik_to_priority(oncelik) -> str:
    try:
        n = int(str(oncelik).split(".")[0])
    except (TypeError, ValueError):
        n = 3
    return _ONCELIK_MAP.get(n, "medium")


async def _import_one(store, ticket: dict) -> list[str]:
    """Tek bir ticket objesini gerçek store API'siyle ekler. Uyarı listesini döner."""
    uyarilar: list[str] = []

    siniflandirma = ticket.get("siniflandirma") or {}
    yonlendirme = ticket.get("yonlendirme") or {}

    modul = siniflandirma.get("modul", "Diger")
    priority = _oncelik_to_priority(siniflandirma.get("oncelik", "3"))

    # sub_category_id: alt_kategori + kategori_grubu isminden çözülür
    alt_kategori = siniflandirma.get("alt_kategori")
    kategori_grubu = siniflandirma.get("kategori_grubu")
    sub_category_id = None
    if alt_kategori and kategori_grubu:
        sub_category_id = store.get_alt_kategori_id(alt_kategori, kategori_grubu)
        if not sub_category_id:
            uyarilar.append(
                f"alt_kategori='{alt_kategori}' / kategori_grubu='{kategori_grubu}' eşleşmedi."
            )

    # sap_module_id: sap_modulu kodundan çözülür
    sap_module_id = None
    sap_modulu = siniflandirma.get("sap_modulu")
    if sap_modulu:
        sap_module_id = store.get_sap_module_id(sap_modulu)
        if not sap_module_id:
            uyarilar.append(f"sap_modulu='{sap_modulu}' eşleşmedi.")

    # assigned_group_id: ekip isminden bulunur (yoksa oluşturulmaz — sadece
    # var olan gerçek ekip kullanılmalı, hayali ekip icat edilmesin)
    group_id = None
    ekip = yonlendirme.get("ekip")
    if ekip:
        group_id = store.get_support_group_id_by_name(ekip)
        if not group_id:
            uyarilar.append(f"ekip='{ekip}' support_groups'ta bulunamadı.")

    # assigned_agent_id: atanan_uzman email'inden bulunur — BU EN ÖNEMLİ ALAN,
    # çünkü get_agents_by_category() fallback'i tam olarak bunu okuyor.
    agent_id = None
    atanan_uzman = yonlendirme.get("atanan_uzman")
    if atanan_uzman:
        agent_id = store.get_user_id_by_email(atanan_uzman)
        if not agent_id:
            uyarilar.append(f"atanan_uzman='{atanan_uzman}' users'ta bulunamadı, assigned_agent_id boş kaldı.")
        elif not group_id:
            # ekip verilmediyse ya da bulunamadıysa, agent'ın GERÇEK grubunu kullan.
            group_id = store.get_user_support_group_id(agent_id)

    tid, tno = store.create_ticket(
        customer_email=ticket.get("customer_email", _VARSAYILAN_MUSTERI_EMAIL),
        recipient_email=ticket.get("recipient_email", _VARSAYILAN_ALICI_EMAIL),
        subject=(ticket.get("subject") or "")[:255],
        raw_issue_description=ticket.get("content", ""),
        extracted_category=modul,
        region=ticket.get("region"),
        status="resolved",  # sentetik geçmiş: zaten çözülmüş kabul edilir
        priority=priority,
        assigned_group_id=group_id,
        assigned_agent_id=agent_id,
        sla_policy_id=None,
        response_deadline=None,
        workaround_deadline=None,
        resolution_deadline=None,
        sub_category_id=sub_category_id,
        sap_module_id=sap_module_id,
    )

    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"kaynak": "postman_seed_sentetik", "siniflandirma": siniflandirma},
        assigned_group_id=group_id,
        assigned_agent_id=agent_id,
        confidence_score=siniflandirma.get("guven", 1.0),
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