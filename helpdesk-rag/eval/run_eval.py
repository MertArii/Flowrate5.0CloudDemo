"""Help desk RAG değerlendirme betiği.

Her soru için pipeline'ı çalıştırır ve iki boyutta puanlar:
  1) RETRIEVAL  — beklenen kaynak dönen kaynaklar arasında mı? (recall@k)
  2) CEVAP      — tipe göre:
       answerable   -> must_include anahtar kelimeleri cevapta geçiyor mu
       should_refuse-> reddetme ifadesi var mı (ve uydurma yapmamış mı)
       smalltalk    -> reddetmemiş ve boş değil mi

Çalıştırma (proje kökünden):
    ./.venv/bin/python eval/run_eval.py
    ./.venv/bin/python eval/run_eval.py --judge   # ek olarak LLM-hakem puanı (yavaş)
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # proje kökü

from app.config import settings
from app.rag import ollama_client, pipeline

REFUSAL_MARK = "elimde bilgi yok"
DATA = Path(__file__).parent / "dataset.json"


def check_retrieval(item: dict, sources: list[dict]) -> bool | None:
    exp = item.get("expected_source")
    if not exp:
        return None  # retrieval bu tip için değerlendirilmez
    return any(s["source"] == exp for s in sources)


def check_answer(item: dict, answer: str) -> bool:
    a = answer.lower().strip()
    refused = REFUSAL_MARK in a
    t = item["type"]
    if t == "answerable":
        if refused:
            return False
        return all(kw.lower() in a for kw in item.get("must_include", []))
    if t == "should_refuse":
        return refused
    if t == "smalltalk":
        return bool(a) and not refused
    return False


async def llm_judge(question: str, reference: str, answer: str) -> int:
    """0-2 arası puan: 0=yanlış, 1=kısmen, 2=doğru. Referansa göre."""
    prompt = (
        "Bir help desk cevabını değerlendir. Sadece tek rakam döndür: "
        "0 (yanlış/alakasız), 1 (kısmen doğru), 2 (doğru ve yeterli).\n\n"
        f"Soru: {question}\nReferans doğru bilgi: {reference}\n"
        f"Değerlendirilecek cevap: {answer}\n\nPuan:"
    )
    msg = await ollama_client.chat([{"role": "user", "content": prompt}])
    txt = (msg.get("content") or "").strip()
    for ch in txt:
        if ch in "012":
            return int(ch)
    return 0


async def main(use_judge: bool):
    data = json.loads(DATA.read_text())
    items = data["items"]
    ret_ok = ret_total = ans_ok = 0
    judge_scores: list[int] = []
    rows = []

    for it in items:
        res = await pipeline.answer(it["question"])
        answer, sources = res["answer"], res["sources"]

        r = check_retrieval(it, sources)
        if r is not None:
            ret_total += 1
            ret_ok += int(r)
        a = check_answer(it, answer)
        ans_ok += int(a)

        judged = ""
        if use_judge and it["type"] == "answerable":
            score = await llm_judge(it["question"], it.get("reference", ""), answer)
            judge_scores.append(score)
            judged = f" | hakem={score}/2"

        rmark = {True: "OK", False: "FAIL", None: "-"}[r]
        print(f"[{it['id']:<10}] retrieval={rmark:<4} cevap={'OK' if a else 'FAIL'}{judged}")
        if not a:
            print(f"    soru : {it['question']}")
            print(f"    cevap: {answer[:160]}")
        rows.append({"id": it["id"], "retrieval": r, "answer_ok": a})

    n = len(items)
    print("\n" + "=" * 50)
    print(f"Retrieval recall@{settings.top_k}: {ret_ok}/{ret_total}"
          f" ({100*ret_ok/ret_total:.0f}%)" if ret_total else "Retrieval: -")
    print(f"Cevap doğruluğu           : {ans_ok}/{n} ({100*ans_ok/n:.0f}%)")
    if judge_scores:
        avg = sum(judge_scores) / len(judge_scores)
        print(f"LLM-hakem ortalaması      : {avg:.2f}/2 ({len(judge_scores)} soru)")
    print("=" * 50)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--judge", action="store_true", help="LLM-hakem puanı ekle (yavaş)")
    args = ap.parse_args()
    asyncio.run(main(args.judge))
