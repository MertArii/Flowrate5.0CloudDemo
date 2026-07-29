import os
import uuid

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel

from app.config import settings
from app.queue import close_pool, enqueue_ingest, job_status
from app.rag import ingest
from app.triage import service as triage_service

app = FastAPI(title="Helpdesk RAG API")


@app.on_event("shutdown")
async def _shutdown():
    await close_pool()


class AskRequest(BaseModel):
    question: str
    min_score: float | None = None   # opsiyonel benzerlik eşiği (0-1)
    # L1 atama için opsiyonel bağlam (tickets kaydına yazılır):
    customer_email: str = "demo@sirket.com"
    recipient_email: str = "destek@sirket.com"
    subject: str | None = None
    region: str | None = None


class TriageRequest(BaseModel):
    text: str
    customer_email: str = "demo@sirket.com"
    recipient_email: str = "destek@sirket.com"
    subject: str | None = None
    region: str | None = None
    min_score: float | None = None   # opsiyonel benzerlik eşiği (0-1)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ingest")
async def ingest_endpoint(
    file: UploadFile = File(...),
    title: str = Form(""),
):
    """Doküman yükle ve indeksle (PDF veya düz metin).

    Redis varsa iş kuyruğa alınır ve hemen job_id döner (büyük dokümanlar
    isteği bloke etmez). Redis yoksa senkron indeksler.
    """
    os.makedirs(settings.upload_dir, exist_ok=True)
    suffix = os.path.splitext(file.filename or "")[1]
    path = os.path.join(settings.upload_dir, f"{uuid.uuid4().hex}{suffix}")
    with open(path, "wb") as f:
        f.write(await file.read())

    source = file.filename or "upload"
    doc_title = title or source

    job_id = await enqueue_ingest(path, source, doc_title)
    if job_id:
        return {"mod": "kuyruk", "job_id": job_id, "filename": source}

    # Redis yok -> senkron indeksle (geliştirme ortamı)
    try:
        parca = await ingest.ingest_file(path, source=source, title=doc_title)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    return {"mod": "senkron", "parca_sayisi": parca, "filename": source}


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    """Kuyruğa alınan ingest işinin durumu."""
    status = await job_status(job_id)
    if status is None:
        raise HTTPException(status_code=503, detail="Kuyruk (Redis) erişilemiyor")
    return status


@app.post("/ask")
async def ask(req: AskRequest):
    """RAG ile soru sor -> kaynaklı cevap + L1 ataması.

    Cevabın yanında soruyu sınıflandırır, doğru ekibe/uzmana yönlendirir ve
    tickets + routing_logs tablolarına kaydeder (bkz. /triage ile aynı motor).
    min_score gönderilirse o istek için benzerlik eşiği uygulanır."""
    r = await triage_service.triage(
        req.question,
        customer_email=req.customer_email,
        recipient_email=req.recipient_email,
        subject=req.subject,
        region=req.region,
        min_score=req.min_score,
    )
    return {
        "answer": r["cevap_metni"],
        "sources": r["tum_kaynaklar"],
        "ticket_id": r["ticket_id"],
        "ticket_number": r["ticket_number"],
        "siniflandirma": r["siniflandirma"],
        "yonlendirme": r["yonlendirme"],
    }


@app.post("/triage")
async def triage(req: TriageRequest):
    """L1 triyaj: ticket'ı sınıflandır, uzmana yönlendir, mümkünse otomatik çöz.
    tickets + routing_logs tablolarına kaydeder."""
    return await triage_service.triage(
        req.text,
        customer_email=req.customer_email,
        recipient_email=req.recipient_email,
        subject=req.subject,
        region=req.region,
        min_score=req.min_score,
    )
