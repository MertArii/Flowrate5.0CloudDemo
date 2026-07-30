import base64
import os
import uuid

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel

from app.config import settings
from app.queue import close_pool, enqueue_ingest, job_status
from app.rag import ingest, vision
from app.triage import service as triage_service

app = FastAPI(title="Helpdesk RAG API")

IMAGE_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/webp"}


@app.on_event("shutdown")
async def _shutdown():
    await close_pool()


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
async def ask(
    question: str = Form(...),
    min_score: float | None = Form(None),
    customer_email: str = Form("demo@sirket.com"),
    recipient_email: str = Form("destek@sirket.com"),
    subject: str | None = Form(None),
    region: str | None = Form(None),
    file: UploadFile | None = File(None),
):
    """RAG ile soru sor -> kaynaklı cevap + L1 ataması.

    Opsiyonel dosya eklenebilir: görsel ise (png/jpg/webp) Qwen3.5 multimodal
    ile doğrudan okunur (OCR gerekmez); PDF/metin ise mevcut ingest mantığıyla
    metni çıkarılır. Her iki durumda da içerik kalıcı olarak
    message_attachments + attachment_vectors'e yazılır — ileride başka
    sorularda da bulunabilir hale gelir.

    Cevabın yanında soruyu sınıflandırır, doğru ekibe/uzmana yönlendirir ve
    tickets + routing_logs tablolarına kaydeder (bkz. /triage ile aynı motor).
    min_score gönderilirse o istek için benzerlik eşiği uygulanır."""
    extra_context = None
    images_b64 = None
    attachment_info = None

    if file is not None:
        os.makedirs(settings.upload_dir, exist_ok=True)
        suffix = os.path.splitext(file.filename or "")[1]
        path = os.path.join(settings.upload_dir, f"{uuid.uuid4().hex}{suffix}")
        raw = await file.read()
        with open(path, "wb") as f:
            f.write(raw)

        content_type = file.content_type or ""
        if content_type in IMAGE_TYPES:
            b64 = base64.b64encode(raw).decode("ascii")
            extra_context = await vision.describe_image(b64)
            images_b64 = [b64]
        else:
            extra_context = ingest.read_file(path)

        attachment_info = {
            "file_name": file.filename or "upload",
            "file_path": path,
            "file_type": content_type or None,
            "extracted_text": extra_context,
        }

    r = await triage_service.triage(
        question,
        customer_email=customer_email,
        recipient_email=recipient_email,
        subject=subject,
        region=region,
        min_score=min_score,
        extra_context=extra_context,
        images_b64=images_b64,
        attachment=attachment_info,
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
    tickets + routing_logs tablolarına kaydeder.

    region gönderilirse ve kategori IT-Donanim ise, aynı bölgedeki uzmana
    öncelik verilir (yonlendirme.istenen_bolge / bolge_eslesti alanlarında
    görünür). SAP kategorilerinde bölge eşleşmesi uygulanmaz."""
    return await triage_service.triage(
        req.text,
        customer_email=req.customer_email,
        recipient_email=req.recipient_email,
        subject=req.subject,
        region=req.region,
        min_score=req.min_score,
    )
