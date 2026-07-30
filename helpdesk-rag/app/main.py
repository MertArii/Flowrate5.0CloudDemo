import os
import uuid

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from pydantic import BaseModel

from app.config import settings
from app.queue import close_pool, enqueue_ingest, job_status
from app.rag import ingest, store, vision
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


class AgentCreateRequest(BaseModel):
    email: str
    full_name: str
    title: str | None = None
    department: str | None = None
    region: str | None = None
    support_group: str          # grup ADI (ör. "BT Destek Ekibi") — id değil
    uzman_kategorileri: list[str] = []   # kategori kodları (ör. ["SAP-MM"])


class CategoryCreateRequest(BaseModel):
    category_key: str
    aciklama: str
    support_group: str          # grup ADI — id değil
    ekip_gorunum_adi: str | None = None


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
    min_score: str | None = Form(None),
    customer_email: str = Form("demo@sirket.com"),
    recipient_email: str = Form("destek@sirket.com"),
    subject: str | None = Form(None),
    region: str | None = Form(None),
    file: UploadFile | None = File(None),
):
    """RAG ile soru sor -> kaynaklı cevap + L1 ataması.

    Opsiyonel dosya eklenebilir: görsel ise (png/jpg/webp) Tesseract ile
    gerçek OCR yapılır (Qwen3.5 görseli GÖRMEZ, sadece çıkan metni yorumlar
    — hata kodu/stack trace gibi kesinlik gereken içerikte parafraz riskini
    önler); PDF/metin ise mevcut ingest mantığıyla metni çıkarılır. Her iki
    durumda da içerik kalıcı olarak message_attachments + attachment_vectors'e
    yazılır — ileride başka sorularda da bulunabilir hale gelir.

    Cevabın yanında soruyu sınıflandırır, doğru ekibe/uzmana yönlendirir ve
    tickets + routing_logs tablolarına kaydeder (bkz. /triage ile aynı motor).
    min_score gönderilirse o istek için benzerlik eşiği uygulanır."""
    # Postman/form-data boş bırakılan alanları None yerine "" gönderir;
    # float alanda bu parse hatası verir, string alanlarda da temizleyelim.
    parsed_min_score = float(min_score) if min_score else None
    region = region or None
    subject = subject or None

    extra_context = None
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
            extra_context = vision.ocr_image(raw)
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
        min_score=parsed_min_score,
        extra_context=extra_context,
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


@app.post("/admin/agents")
async def create_agent(req: AgentCreateRequest):
    """Yeni bir uzman (agent) ekler. Grup ADI ile çalışır (id değil) —
    yanlış/rastgele bir grup ID'si elle kopyalanıp yanlış ekibe bağlanma
    hatasını önler. Kategori kodları da (varsa) gerçekten var olup
    olmadığı kontrol edilir; DB'ye yazmadan önce açık hata döner."""
    group_id = store.get_support_group_id_by_name(req.support_group)
    if not group_id:
        raise HTTPException(
            status_code=400,
            detail=f"'{req.support_group}' adında bir destek grubu yok. "
                   f"Mevcut gruplar: {store.get_all_group_names()}",
        )

    if req.uzman_kategorileri:
        gecerli = set(store.get_all_category_keys())
        gecersiz = [k for k in req.uzman_kategorileri if k not in gecerli]
        if gecersiz:
            raise HTTPException(
                status_code=400,
                detail=f"Geçersiz kategori(ler): {gecersiz}. "
                       f"Mevcut kategoriler: {sorted(gecerli)}",
            )

    user_id = store.create_agent(
        email=req.email, full_name=req.full_name, title=req.title,
        department=req.department, region=req.region,
        support_group_id=group_id, uzman_kategorileri=req.uzman_kategorileri,
    )
    return {
        "id": user_id, "email": req.email, "support_group": req.support_group,
        "uzman_kategorileri": req.uzman_kategorileri,
    }


@app.post("/admin/categories")
async def create_category(req: CategoryCreateRequest):
    """Yeni bir sınıflandırma kategorisi ekler. Grup ADI ile çalışır (id
    değil). Kategori listesi önbelleksiz, her classify() çağrısında DB'den
    taze çekildiği için eklendiği an kullanılabilir — restart gerekmez."""
    group_id = store.get_support_group_id_by_name(req.support_group)
    if not group_id:
        raise HTTPException(
            status_code=400,
            detail=f"'{req.support_group}' adında bir destek grubu yok. "
                   f"Mevcut gruplar: {store.get_all_group_names()}",
        )

    category_id = store.create_category(
        category_key=req.category_key, aciklama=req.aciklama,
        ekip_group_id=group_id, ekip_gorunum_adi=req.ekip_gorunum_adi,
    )
    return {
        "id": category_id, "category_key": req.category_key,
        "support_group": req.support_group,
    }
