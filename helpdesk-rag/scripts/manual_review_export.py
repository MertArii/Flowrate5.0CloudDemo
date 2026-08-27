"""scripts/manual_review_export.py

Şüpheli çözüm metni gruplarını, ELLE incelemeniz için okunabilir bir
rapora (Markdown) döker. Docker, Ollama, embedding YOK — sadece JSON
dosyasını okur, scan_data_quality.py ile aynı mantıkla gruplar, ama
sonucu insan gözüyle karar vermeye uygun bir formatta sunar.

Çalıştırma (yerelde, docker'a hiç gerek yok):
    python3 scripts/manual_review_export.py

Çıktı: scripts/manual_review.md
  Her grup için:
    - Çözüm metninin TAMAMI (kısaltılmadan)
    - Tekrar sayısı, farklı problem sayısı
    - O çözüme bağlı problem cümlelerinden bir örnek listesi (en fazla 8 tane,
      hepsi farklıysa hepsi gösterilir)
    - Elle doldurmanız için boş bir "KARAR:" satırı (KİRLİ / TEMİZ / ŞÜPHELİ yazın)

En yüksek tekrar sayısından en düşüğe doğru sıralanır (önce en büyük gruplara
bakmak, en çok kaydı etkileyen kararları önce vermenizi sağlar).
"""
import json
from collections import defaultdict
from pathlib import Path

DATA_FILE = Path(__file__).resolve().parent.parent / "sla" / "emails_sla_seviyeli.json"
OUTPUT_FILE = Path(__file__).resolve().parent / "manual_review.md"

MIN_TEKRAR = 3       # bu sayının altındaki tekrarları rapora dahil etme
MAX_ORNEK = 8        # her grup için en fazla kaç örnek problem cümlesi gösterilsin


def _grupla(data: list[dict]) -> dict[str, list[dict]]:
    gruplar: dict[str, list[dict]] = defaultdict(list)
    for rec in data:
        cozum = (rec.get("cozum") or "").strip()
        sorun = (rec.get("sorun_aciklamasi") or "").strip()
        if not cozum or not sorun:
            continue
        gruplar[cozum].append(rec)
    return gruplar


def main() -> None:
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    gruplar = _grupla(data)

    supheli = {
        cozum: kayitlar for cozum, kayitlar in gruplar.items()
        if len(kayitlar) >= MIN_TEKRAR
    }
    print(f"[rapor] {len(gruplar)} benzersiz çözüm metni, {len(supheli)} tanesi "
          f"{MIN_TEKRAR}+ kez tekrarlanmış (rapora dahil edilecek).")

    # Tekrar sayısına göre büyükten küçüğe sırala
    siralanmis = sorted(supheli.items(), key=lambda kv: -len(kv[1]))

    satirlar = ["# Manuel İnceleme Raporu\n",
                f"Toplam {len(siralanmis)} grup, tekrar sayısına göre sıralı.\n",
                "Her grubun altına `KARAR:` yazan satıra KİRLİ / TEMİZ / ŞÜPHELİ yazın.\n",
                "---\n"]

    for i, (cozum, kayitlar) in enumerate(siralanmis, 1):
        farkli_problemler = sorted({rec["sorun_aciklamasi"].strip() for rec in kayitlar})
        farkli_sayi = len(farkli_problemler)
        ticket_idler = [str(rec.get("ticket_id")) for rec in kayitlar]

        satirlar.append(f"## Grup {i} — x{len(kayitlar)} tekrar, {farkli_sayi} farklı problem\n")
        satirlar.append(f"**Çözüm metni:** {cozum}\n")
        satirlar.append(f"**Etkilenen ticket_id'ler:** {', '.join(ticket_idler[:20])}"
                         + (" ..." if len(ticket_idler) > 20 else "") + "\n")
        satirlar.append("**Örnek problem cümleleri:**")
        for p in farkli_problemler[:MAX_ORNEK]:
            satirlar.append(f"  - {p}")
        if farkli_sayi > MAX_ORNEK:
            satirlar.append(f"  - ... (+{farkli_sayi - MAX_ORNEK} tane daha)")
        satirlar.append("\n**KARAR:** \n")
        satirlar.append("---\n")

    OUTPUT_FILE.write_text("\n".join(satirlar), encoding="utf-8")
    print(f"[rapor] Yazıldı: {OUTPUT_FILE}")
    print("Bu dosyayı bir metin editöründe (VS Code) açıp, her grubun altındaki "
          "'KARAR:' satırına KİRLİ / TEMİZ / ŞÜPHELİ yazarak ilerleyin.")


if __name__ == "__main__":
    main()