"""sla/emails_sla_seviyeli.json'daki geçmiş ticket'ları canlı şemaya aktarır.

Sadece GÜVENİLİR alt küme alınır: kaynak == 'orijinal' (sentetik/augmented
değil), kayit_turu == 'duzenli' (SLA modelinin kendi ayrımına göre temiz/
gürültüsüz), ve cozum/atanan_kisi/sla_level_normalize dolu olanlar.
Augmented + gürültülü kayıtlar RAG bilgi bankasını neredeyse-tekrar eden
parçalarla şişirmemesi için bilinçli olarak DIŞARIDA bırakılıyor.

Her ticket için:
  1. classifier.classify() (LLM) ile GERÇEK kategori belirlenir
     (extracted_category + ticket_solutions.category için).
  2. atanan_kisi DB'de yoksa yeni bir agent (users) oluşturulur.
  3. sla_level_normalize -> priority -> sla_policies eşlemesiyle SLA
     deadline'ları hesaplanır; ~%6 ihtimalle kasıtlı SLA ihlali simüle edilir
     (sla_status='outside_sla', resolved_at deadline'ı aşar).
  4. sorun_aciklamasi embed edilip ticket_solutions'a (RAG Katman 1) yazılır.

Yarıda kesilirse GÜVENLE tekrar çalıştırılabilir: her kayıt, ticket_id'si
zaten ticket_solutions.metadata->>'harici_no' olarak var mı diye önce
kontrol edilir, varsa atlanır (store.solution_exists_for_harici_no).

Çalıştırma (api container içinde, Ollama + Postgres erişimi olan yerde):
    docker compose -f docker-compose.demo.yml exec api python scripts/import_sla_dataset.py
    docker compose -f docker-compose.demo.yml exec api python scripts/import_sla_dataset.py --limit 100

--limit N verilirse, bu ÇALIŞTIRMADA en fazla N YENİ kayıt işlenir (zaten
işlenmiş/atlanan kayıtlar sayılmaz) ve script temiz şekilde durur. Sonraki
çalıştırma (limitli ya da limitsiz) resumability sayesinde kaldığı yerden
devam eder — --limit vermek "durdur/devam ettir" akışını bozmaz.

NOT: 4270 kayıt için LLM sınıflandırma + embedding üretimi SAATLER
sürebilir (her kayıt için 2 model çağrısı). İlerleme her 100 kayıtta bir
loglanır. Arkaplanda çalıştırmak isterseniz:
    docker compose -f docker-compose.demo.yml exec -d api python scripts/import_sla_dataset.py \
        > /code/data/import_sla.log 2>&1
"""
from __future__ import annotations

import argparse
import asyncio
import json
import random
from datetime import datetime, timedelta
from pathlib import Path

from app.rag import ollama_client, store
from app.triage import classifier, sla

DATA_FILE = Path(__file__).resolve().parent.parent / "sla" / "emails_sla_seviyeli.json"

# atanan_kisi 'kime' domain'inden yeni agent için destek grubu tahmini —
# sadece LLM kategorisi 'Diger' dönüp gerçek bir ekip bulunamadığında devreye
# girer (asıl kategori->ekip eşlemesi her zaman classification_categories'ten,
# yani canlı/güncel taksonomiden gelir).
FALLBACK_GROUP_BY_RECIPIENT = {
    "sapdestek@gmail.com": "SAP Danışman Ekibi",
    "btdestek@gmail.com": "BT Destek Ekibi",
}
FALLBACK_GROUP_DEFAULT = "Genel Triyaj"

_ONCELIK_MAP = {1: "urgent", 2: "high", 3: "medium", 4: "low", 5: "planned"}

SLA_IHLAL_ORANI = 0.06  # complete_migration.py'deki simülasyonla aynı oran


def _agent_email(name: str) -> str:
    base = name.strip().lower().replace(" ", ".")
    tr = str.maketrans("çğıöşü", "cgiosu")
    return base.translate(tr) + "@sirket.com"


def _load_temiz_kayitlar() -> list[dict]:
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    return [
        r for r in data
        if r.get("kaynak") == "orijinal"
        and r.get("kayit_turu") == "duzenli"
        and r.get("cozum")
        and r.get("atanan_kisi")
        and r.get("sla_level_normalize") in (1, 2, 3, 4, 5)
    ]


async def _get_or_create_agent(atanan_kisi: str, kategori_ekip: str | None, kime: str) -> tuple[str, str]:
    """(agent_id, support_group_id) döner; agent yoksa oluşturur.

    Agent ZATEN varsa, ticket'a onun GERÇEK (users.support_group_id) grubu
    atanır — bu ticket'ın LLM kategorisinden yeniden tahmin edilmez, aksi
    halde mevcut bir uzman, kendi gerçek ekibinden farklı bir gruba
    bağlanmış bir ticket'la eşleşebilir (tutarsız veri)."""
    email = _agent_email(atanan_kisi)
    agent_id = store.get_user_id_by_email(email)

    if agent_id:
        group_id = store.get_user_support_group_id(agent_id)
        if group_id:
            return agent_id, group_id
        # Uzmanın kaydı var ama bir gruba bağlı değil — aşağıdaki tahminle devam.

    grup_adi = kategori_ekip or FALLBACK_GROUP_BY_RECIPIENT.get(kime, FALLBACK_GROUP_DEFAULT)
    group_id = store.get_or_create_support_group(grup_adi)

    if agent_id:
        return agent_id, group_id

    full = atanan_kisi.split(".")[0].capitalize() + " " + atanan_kisi.split(".")[-1].capitalize()
    agent_id = store.create_agent(
        email=email, full_name=full, title="Destek Uzmanı",
        department="Bilgi Teknolojileri", region=None,
        support_group_id=group_id, uzman_kategorileri=None,
    )
    return agent_id, group_id


async def _import_one(rec: dict) -> bool:
    """Kaydı işler; zaten daha önce içe aktarılmışsa atlar. İşlendiyse True,
    atlandıysa False döner."""
    harici_no = str(rec["ticket_id"])
    if store.solution_exists_for_harici_no(harici_no):
        return False  # zaten işlenmiş (yarıda kesilip devam eden çalıştırma)

    sorun = rec["sorun_aciklamasi"]
    cozum = rec["cozum"]

    # 1) Gerçek kategori — LLM.
    siniflandirma = await classifier.classify(f"{rec['konu']}\n\n{sorun}")
    modul = siniflandirma["modul"]
    kategoriler = store.get_categories()
    ekip = kategoriler.get(modul, {}).get("ekip")

    # 1b) Alt kategori + SAP modülü — classify() zaten ust_kategori/
    # kategori_grubu/alt_kategori/sap_modulu alanlarını hiyerarşiye karşı
    # doğrulanmış olarak döndürüyor (geçersizse None). İsim -> id çevirimi.
    sub_category_id = store.get_alt_kategori_id(
        siniflandirma.get("alt_kategori"), siniflandirma.get("kategori_grubu"),
    )
    sap_module_id = store.get_sap_module_id(siniflandirma.get("sap_modulu"))

    # 2) Agent + destek grubu.
    agent_id, group_id = await _get_or_create_agent(rec["atanan_kisi"], ekip, rec["kime"])

    # 3) Müşteri.
    customer_id = store.get_or_create_customer(
        rec["kullanici_maili"],
        rec["kullanici_maili"].split("@")[0].replace(".", " ").title(),
        rec.get("bolge"),
    )

    # 4) SLA / zaman çizelgesi.
    priority = _ONCELIK_MAP[rec["sla_level_normalize"]]
    sla_policy = store.get_sla_policy(priority)
    created_at = datetime.now() - timedelta(days=random.randint(1, 180), hours=random.randint(0, 23))
    deadlines = sla.compute_deadlines(created_at, sla_policy) if sla_policy else {}

    ihlal = random.random() < SLA_IHLAL_ORANI
    res_deadline = deadlines.get("resolution_deadline")
    if ihlal and res_deadline:
        resolved_at = res_deadline + timedelta(hours=random.randint(1, 48))
        sla_status = "outside_sla"
    else:
        resolved_at = created_at + timedelta(hours=random.randint(1, 48))
        sla_status = "within_sla"

    # 5) Ticket.
    tid, _tno = store.create_ticket(
        customer_email=rec["kullanici_maili"],
        recipient_email=rec["kime"],
        subject=rec["konu"][:255],
        raw_issue_description=sorun,
        extracted_category=modul,
        region=rec.get("bolge"),
        status="resolved",
        priority=priority,
        assigned_group_id=group_id,
        assigned_agent_id=agent_id,
        sla_policy_id=sla_policy["id"] if sla_policy else None,
        response_deadline=deadlines.get("response_deadline"),
        workaround_deadline=deadlines.get("workaround_deadline"),
        resolution_deadline=res_deadline,
        sub_category_id=sub_category_id,
        sap_module_id=sap_module_id,
    )
    # customer_id / created_at / resolved_at / sla_status: create_ticket bu
    # alanları desteklemiyor (canlı akışta hep 'yeni' ticket açılır) — toplu
    # import için gerekli, o yüzden ayrı bir UPDATE ile tamamlanıyor.
    store.backfill_ticket_history(
        ticket_id=tid, customer_id=customer_id,
        created_at=created_at, resolved_at=resolved_at, sla_status=sla_status,
    )

    # 6) Mesaj zinciri (müşteri sorusu + uzman çözümü).
    store.create_ticket_message(
        ticket_id=tid, sender_email=rec["kullanici_maili"], sender_type="customer",
        message_body=sorun,
    )
    store.create_ticket_message(
        ticket_id=tid, sender_email=_agent_email(rec["atanan_kisi"]), sender_type="agent",
        message_body=cozum,
    )

    # 7) RAG Katman 1 — embed + ticket_solutions.
    emb = await ollama_client.embed(sorun)
    store.create_ticket_solution(
        ticket_id=tid, category=modul, problem_text=sorun, solution_text=cozum,
        embedding=emb,
        metadata={
            "harici_no": harici_no, "bolge": rec.get("bolge"),
            "uzman": rec["atanan_kisi"], "kaynak": rec.get("kaynak"),
            "kayit_turu": rec.get("kayit_turu"),
        },
    )

    # 8) İzlenebilirlik.
    store.create_routing_log(
        ticket_id=tid,
        decision_factors={"kaynak": "toplu_import_sla_dataset", "siniflandirma": siniflandirma},
        assigned_group_id=group_id, assigned_agent_id=agent_id,
        confidence_score=siniflandirma["guven"],
    )
    return True


async def main(limit: int | None) -> None:
    kayitlar = _load_temiz_kayitlar()
    print(f"[import] {len(kayitlar)} temiz kayıt bulundu (orijinal+duzenli+dolu alanlar).")
    if limit:
        print(f"[import] --limit {limit}: bu çalıştırmada en fazla {limit} YENİ kayıt işlenip duracak.")
    store.open_pool()
    try:
        islenen = atlanan = 0
        for i, rec in enumerate(kayitlar):
            if limit and islenen >= limit:
                print(f"[import] Limit'e ({limit}) ulaşıldı, temiz şekilde duruluyor. "
                      f"Devam etmek için script'i tekrar çalıştırın (kaldığı yerden devam eder).")
                break
            try:
                if await _import_one(rec):
                    islenen += 1
                else:
                    atlanan += 1
            except Exception as e:
                print(f"[import] HATA (ticket_id={rec.get('ticket_id')}): {e}")

            if (i + 1) % 100 == 0:
                print(f"[import] {i + 1}/{len(kayitlar)} — işlenen: {islenen}, atlanan (zaten vardı): {atlanan}")

        print(f"[import] TAMAM (bu çalıştırma). İşlenen: {islenen}, atlanan: {atlanan}, toplam veri seti: {len(kayitlar)}")
    finally:
        store.close_pool()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None,
                     help="Bu çalıştırmada işlenecek en fazla YENİ kayıt sayısı (verilmezse tümü).")
    args = ap.parse_args()
    asyncio.run(main(args.limit))
