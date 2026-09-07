"""47 'Diger' ticket'i, canli sistemin ayni classifier.classify() cagrisiyla
yeniden siniflandirir (import_sla_dataset.py ile ayni metod: subject+\n\n+desc).
Konteyner icinde (docker exec) calistirilmak uzere yazildi."""
import asyncio
import json

from app.rag import store
from app.triage import classifier


async def main():
    store.open_pool()
    with open("/tmp/diger_tickets.json", encoding="utf-8") as f:
        items = json.load(f)

    sonuc = []
    for i, item in enumerate(items):
        text = f"{item['subject']}\n\n{item['description']}"
        c = await classifier.classify(text)
        sonuc.append({
            "row": item["row"],
            "subject": item["subject"],
            "modul": c["modul"],
            "guven": c["guven"],
        })
        print(f"[{i+1}/{len(items)}] satir {item['row']:<5} -> {c['modul']:<15} (güven {c['guven']:.2f})  {item['subject'][:50]}", flush=True)

    with open("/tmp/diger_sonuc.json", "w", encoding="utf-8") as f:
        json.dump(sonuc, f, ensure_ascii=False, indent=2)


asyncio.run(main())
