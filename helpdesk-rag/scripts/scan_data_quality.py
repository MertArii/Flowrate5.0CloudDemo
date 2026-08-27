"""Toplu import öncesi/sonrası veri kalite taraması (Katman 1, madde 1+2).

emails_sla_seviyeli.json içindeki 'temiz' kabul edilen kayıtları
(import_sla_dataset.py'deki _load_temiz_kayitlar ile aynı filtre) tarar ve
iki şüpheli deseni raporlar:

  1) BİREBİR TEKRAR EDEN ÇÖZÜM: aynı cozum metni, TEKRAR_ESIGI'nden fazla
     kayıtta birebir aynıysa şüpheli sayılır (muhtemelen placeholder/dummy
     bir değer, gerçek uzman cevabı olma ihtimali düşük).

  2) ÇEŞİTLİ PROBLEM + SABİT ÇÖZÜM: bir cozum metni birden fazla FARKLI
     sorun_aciklamasi ile eşleşiyorsa (yani aynı cevap gerçekten farklı
     sorunlara veriliyormuş gibi görünüyorsa) bu, cozum'un genel/şablon bir
     metin olduğuna işaret eder — 1'i tetiklemese bile (az sayıda tekrar
     etse bile) not edilir.

Bu script SADECE JSON dosyasını okur; DB/LLM/embedding'e ihtiyaç duymaz,
bu yüzden saniyeler içinde biter ve import_sla_dataset.py'den ÖNCE, her
JSON güncellemesinde bir "sağlık kontrolü" olarak çalıştırılabilir.

Çalıştırma (düz Python, docker/DB gerekmez):
    python3 scripts/scan_data_quality.py

Çıktı: terminale özet rapor + (varsa) şüpheli kayıtların ticket_id'lerini
scripts/data_quality_report.json dosyasına yazar — import öncesi elle
gözden geçirmek veya import_sla_dataset.py'ye filtre olarak vermek için.
"""
from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path

DATA_FILE = Path(__file__).resolve().parent.parent / "sla" / "emails_sla_seviyeli.json"
REPORT_FILE = Path(__file__).resolve().parent / "data_quality_report.json"

# Bir çözüm metni, bu sayıdan FAZLA kayıtta birebir aynıysa şüpheli sayılır.
# "Bilgisayar yavaş açılıyor" gibi meşru ama gerçek tekrarları elemek için
# çok düşük tutulmamalı; deneyimsel bir başlangıç değeri, veri setinize
# göre ayarlayın.
TEKRAR_ESIGI = 5

# Aynı çözüm metni, en az bu kadar FARKLI problem cümlesiyle eşleşiyorsa
# (tekrar sayısı eşiği geçmese bile) "genel/şablon cevap" olarak işaretlenir.
COESITLILIK_ESIGI = 3


def _load_temiz_kayitlar() -> list[dict]:
    """import_sla_dataset.py'deki filtreyle birebir aynı — iki script'in
    aynı 'temiz' alt kümeye baktığından emin olmak için kasıtlı olarak
    tekrarlanmıştır (ileride ortak bir modüle taşınabilir)."""
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    return [
        r for r in data
        if r.get("kaynak") == "orijinal"
        and r.get("kayit_turu") == "duzenli"
        and r.get("cozum")
        and r.get("atanan_kisi")
        and r.get("sla_level_normalize") in (1, 2, 3, 4, 5)
    ]


def tara() -> dict:
    kayitlar = _load_temiz_kayitlar()

    cozum_sayaci: Counter[str] = Counter()
    cozum_problem_map: dict[str, set[str]] = defaultdict(set)
    cozum_ticketlar: dict[str, list[str]] = defaultdict(list)

    for r in kayitlar:
        cozum = (r.get("cozum") or "").strip()
        problem = (r.get("sorun_aciklamasi") or "").strip()
        if not cozum:
            continue
        cozum_sayaci[cozum] += 1
        cozum_problem_map[cozum].add(problem)
        cozum_ticketlar[cozum].append(str(r.get("ticket_id")))

    # 1) Birebir tekrar eden çözümler.
    tekrar_edenler = {
        cozum: adet for cozum, adet in cozum_sayaci.items()
        if adet > TEKRAR_ESIGI
    }

    # 2) Çeşitli problem + sabit çözüm (tekrar eşiğini geçmese bile).
    sablon_supheliler = {
        cozum: len(problemler) for cozum, problemler in cozum_problem_map.items()
        if len(problemler) >= COESITLILIK_ESIGI
    }

    # Rapor: iki kümenin birleşimi, her biri için ticket_id listesiyle.
    supheli_hepsi = set(tekrar_edenler) | set(sablon_supheliler)
    rapor = {
        "toplam_temiz_kayit": len(kayitlar),
        "supheli_cozum_sayisi": len(supheli_hepsi),
        "supheli_detay": [
            {
                "cozum": cozum,
                "tekrar_sayisi": cozum_sayaci[cozum],
                "farkli_problem_sayisi": len(cozum_problem_map[cozum]),
                "ticket_idler": sorted(set(cozum_ticketlar[cozum]), key=lambda x: (len(x), x)),
            }
            for cozum in sorted(supheli_hepsi, key=lambda c: -cozum_sayaci[c])
        ],
    }
    return rapor


def main() -> None:
    rapor = tara()

    print(f"[tarama] {rapor['toplam_temiz_kayit']} temiz kayıt tarandı.")
    print(f"[tarama] {rapor['supheli_cozum_sayisi']} şüpheli çözüm metni bulundu.\n")

    for detay in rapor["supheli_detay"]:
        print(
            f"  x{detay['tekrar_sayisi']:>3}  ({detay['farkli_problem_sayisi']} farklı problem)  "
            f"-> {detay['cozum'][:80]}"
        )

    REPORT_FILE.write_text(
        json.dumps(rapor, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n[tarama] Ayrıntılı rapor yazıldı: {REPORT_FILE}")


if __name__ == "__main__":
    main()