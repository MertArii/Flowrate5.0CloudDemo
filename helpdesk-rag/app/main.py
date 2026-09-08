"""Helpdesk RAG API — ana uygulama modülü.

Stabilite ve hata dayanıklılığı:
  - Global exception handler'lar: tüm hatalar temiz JSON olarak döner
  - Yapılandırılmış loglama: her istek/hata loglanır
  - Startup bağımlılık kontrolü: DB + Ollama açılışta test edilir
  - Health check: bağımlılık durumlarını gerçekten test eder
  - Langfuse: izleme dekoratörleri doğru sırada
"""
from langfuse import observe
import os
import time
import uuid

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.config import settings
from app.exceptions import AppError
from app.logging_config import get_logger, setup_logging
from app.queue import close_pool as close_redis_pool, enqueue_ingest, job_status
from app.rag import ingest, store, vision
from app.triage import service as triage_service

# Loglama altyapısını başlat (modül importlarından önce)
setup_logging()
logger = get_logger(__name__)

app = FastAPI(title="Helpdesk RAG API")

IMAGE_TYPES = {"image/png", "image/jpeg", "image/jpg", "image/webp"}


# ---- Global Exception Handler'lar -------------------------------------------

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    """Tüm özel uygulama hatalarını temiz JSON olarak döner.
    Kullanıcıya ham traceback göstermez."""
    logger.error(
        "AppError: %s",
        exc.detail,
        extra={
            "error_type": type(exc).__name__,
            "status_code": exc.status_code,
            "endpoint": str(request.url.path),
            "method": request.method,
        },
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": type(exc).__name__, "detail": exc.detail},
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """Kötü istek formatı (eksik alan, yanlış tip) için açıklayıcı hata."""
    errors = []
    for err in exc.errors():
        loc = " → ".join(str(l) for l in err.get("loc", []))
        errors.append(f"{loc}: {err.get('msg', 'geçersiz değer')}")
    detail = "; ".join(errors)
    logger.warning(
        "Validation error: %s",
        detail,
        extra={"endpoint": str(request.url.path), "method": request.method},
    )
    return JSONResponse(
        status_code=422,
        content={"error": "ValidationError", "detail": detail},
    )


@app.exception_handler(Exception)
async def generic_error_handler(request: Request, exc: Exception):
    """Yakalanmamış tüm hatalar için güvenlik ağı. Kullanıcıya iç detay
    sızdırmaz, arka planda tam traceback loglar."""
    logger.exception(
        "Yakalanmamış hata: %s",
        str(exc),
        extra={
            "error_type": type(exc).__name__,
            "endpoint": str(request.url.path),
            "method": request.method,
        },
    )
    return JSONResponse(
        status_code=500,
        content={
            "error": "InternalServerError",
            "detail": "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.",
        },
    )


# ---- Middleware: istek loglama ------------------------------------------------

@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    """Her isteği loglar: başlangıç, süre ve yanıt kodu."""
    request_id = str(uuid.uuid4())[:8]
    start = time.monotonic()

    logger.info(
        "→ %s %s",
        request.method,
        request.url.path,
        extra={"request_id": request_id, "method": request.method,
               "endpoint": request.url.path},
    )

    response = await call_next(request)
    duration_ms = round((time.monotonic() - start) * 1000, 1)

    logger.info(
        "← %s %s %d (%.1fms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
        extra={"request_id": request_id, "status_code": response.status_code,
               "duration_ms": duration_ms, "endpoint": request.url.path},
    )
    return response


# ---- Lifecycle Events --------------------------------------------------------

@app.on_event("startup")
async def _startup():
    """Uygulama başlarken bağımlılıkları kontrol eder."""
    logger.info("Uygulama başlatılıyor...")

    # 1. Veritabanı bağlantısı
    try:
        store.open_pool()
        logger.info("✓ Veritabanı bağlantısı başarılı.")
    except Exception:
        logger.exception("✗ Veritabanı bağlantısı başarısız!")
        # DB olmadan uygulama çalışamaz, ama container orchestrator
        # health check ile yeniden başlatabilsin diye başlatmaya devam et

    # 2. Ollama erişim testi (opsiyonel — yoksa sadece uyar)
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{settings.ollama_base_url}/api/tags")
            r.raise_for_status()
            models = [m["name"] for m in r.json().get("models", [])]
            logger.info("✓ Ollama erişilebilir. Yüklü modeller: %s", models)
    except Exception as exc:
        logger.warning(
            "✗ Ollama'ya ulaşılamıyor (%s). Model çağrıları başarısız olacak.",
            exc,
        )

    logger.info("Uygulama başlatıldı.")


@app.on_event("shutdown")
async def _shutdown():
    """Uygulama kapanırken kaynakları temizler."""
    logger.info("Uygulama kapatılıyor...")

    # Redis pool
    try:
        await close_redis_pool()
    except Exception:
        logger.exception("Redis pool kapatılırken hata")

    # DB pool
    try:
        store.close_pool()
    except Exception:
        logger.exception("DB pool kapatılırken hata")

    # Langfuse flush
    try:
        from langfuse import get_client
        get_client().flush()
        logger.info("Langfuse flush tamamlandı.")
    except Exception:
        logger.debug("Langfuse flush atlandı (yapılandırılmamış olabilir).")

    logger.info("Uygulama kapatıldı.")


# ---- Request Models ----------------------------------------------------------

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


class FeedbackRequest(BaseModel):
    agent_email: str            # puanı veren uzmanın e-postası — id değil
    rating: int                 # 1-5
    feedback_text: str | None = None


# ---- Endpoints ---------------------------------------------------------------

@app.get("/health")
async def health():
    """Bağımlılıkların gerçek durumunu test eder.

    Yanıt:
        status: "healthy" (tümü çalışıyor) veya "degraded" (bir/daha fazla sorunlu)
        dependencies: her bağımlılığın ayrı durumu
    """
    deps = {}

    # DB testi
    try:
        with store._connect() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        deps["database"] = {"status": "ok"}
    except Exception as exc:
        deps["database"] = {"status": "error", "detail": str(exc)}

    # Ollama testi
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{settings.ollama_base_url}/api/tags")
            r.raise_for_status()
        deps["ollama"] = {"status": "ok"}
    except Exception as exc:
        deps["ollama"] = {"status": "error", "detail": str(exc)}

    # Redis testi
    try:
        from app.queue import get_pool
        pool = await get_pool()
        if pool:
            deps["redis"] = {"status": "ok"}
        else:
            deps["redis"] = {"status": "unavailable", "detail": "Pool alınamadı"}
    except Exception as exc:
        deps["redis"] = {"status": "error", "detail": str(exc)}

    all_ok = all(d["status"] == "ok" for d in deps.values())
    return {
        "status": "healthy" if all_ok else "degraded",
        "dependencies": deps,
    }


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
        logger.info("Ingest kuyruğa alındı", extra={"job_id": job_id, "source": source})
        return {"mod": "kuyruk", "job_id": job_id, "filename": source}

    # Redis yok -> senkron indeksle (geliştirme ortamı)
    try:
        parca = await ingest.ingest_file(path, source=source, title=doc_title)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    logger.info("Senkron ingest tamamlandı", extra={"source": source, "parca": parca})
    return {"mod": "senkron", "parca_sayisi": parca, "filename": source}


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    """Kuyruğa alınan ingest işinin durumu."""
    status = await job_status(job_id)
    if status is None:
        raise HTTPException(status_code=503, detail="Kuyruk (Redis) erişilemiyor")
    return status


@app.post("/ask")
@observe()
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
    parsed_min_score = None
    if min_score:
        try:
            parsed_min_score = float(min_score)
        except ValueError:
            raise HTTPException(
                status_code=422, detail=f"min_score geçerli bir sayı değil: '{min_score}'"
            )
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
        is_image = content_type in IMAGE_TYPES or suffix.lower() in [".png", ".jpg", ".jpeg", ".webp"]
        
        if is_image:
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
@observe()
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
@observe()
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
    logger.info("Yeni uzman eklendi", extra={"email": req.email, "group": req.support_group})
    return {
        "id": user_id, "email": req.email, "support_group": req.support_group,
        "uzman_kategorileri": req.uzman_kategorileri,
    }


@app.get("/admin/sla-ihlaller")
@observe()
async def sla_ihlaller():
    """Süresi geçmiş (ilk müdahale veya çözüm deadline'ı aşılmış) ve hâlâ
    açık olan ticket'ları listeler. Anlık sorgu — periyodik bir arka plan
    işi değil, her çağrıda taze hesaplanır."""
    return {"ihlaller": store.get_sla_violations()}


@app.post("/admin/categories")
@observe()
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
    logger.info("Yeni kategori eklendi", extra={"category_key": req.category_key})
    return {
        "id": category_id, "category_key": req.category_key,
        "support_group": req.support_group,
    }


@app.post("/messages/{message_id}/feedback")
@observe()
async def submit_feedback(message_id: str, req: FeedbackRequest):
    """Bir uzmanın, AI'ın ürettiği taslak çözüme (ai_generated_draft) verdiği
    puanı kaydeder. Puan 4 veya 5 ise VE bu ticket için henüz bir
    ticket_solutions kaydı yoksa, ticket'ın sorun metni + AI taslağı
    doğrulanmış bir çözüm olarak ticket_solutions'a (RAG Katman 1) embed
    edilip eklenir — böylece gelecekteki benzer ticket'larda otomatik
    çözüm önerisi olarak bulunabilir hale gelir.

    Düşük puanlı (<=3) taslaklar KB'ye eklenmez — sadece geri bildirim
    olarak kaydedilir; bu, RAG'in kendi hatalı cevaplarını doğrulama
    yapılmadan tekrar tekrar önermesini (self-reinforcing hallucination)
    önlemek içindir."""
    from app.rag import ollama_client

    if not (1 <= req.rating <= 5):
        raise HTTPException(status_code=400, detail="rating 1-5 arasında olmalı.")

    msg = store.get_ai_message(message_id)
    if not msg:
        raise HTTPException(status_code=404, detail=f"'{message_id}' id'sinde bir mesaj yok.")
    if msg["sender_type"] != "ai_bot" or not msg["ai_generated_draft"]:
        raise HTTPException(
            status_code=400,
            detail="Bu mesaj bir AI taslağı değil (ai_generated_draft boş) — puanlanamaz.",
        )

    agent_id = store.get_user_id_by_email(req.agent_email)
    if not agent_id:
        raise HTTPException(status_code=400, detail=f"'{req.agent_email}' adında bir kullanıcı yok.")

    store.create_ai_feedback(
        message_id=message_id, user_id=agent_id,
        rating=req.rating, feedback_text=req.feedback_text,
    )

    terfi_edildi = False
    if req.rating >= 4 and not store.ticket_solution_exists(msg["ticket_id"]):
        ticket = store.get_ticket(msg["ticket_id"])
        if ticket and ticket["raw_issue_description"]:
            # GELİŞTİRME ORTAMI: Sentetik verilerin sisteme sızmasını engellemek 
            # için dinamik öğrenme (ticket_solutions'a ekleme) geçici olarak askıya alındı. Üretim ortamında bu blok açılabilir.
            ##emb = await ollama_client.embed(ticket["raw_issue_description"])
            #store.create_ticket_solution(
                #ticket_id=msg["ticket_id"],
                ###category=ticket["extracted_category"],
               #### problem_text=ticket["raw_issue_description"],
               ##### solution_text=msg["ai_generated_draft"],
                ######embedding=emb,
               ## metadata={"kaynak": "ai_feedback", "rating": req.rating,
                          ##"onaylayan": req.agent_email},
            #)
            ##terfi_edildi = True
            pass

    logger.info(
        "Feedback kaydedildi",
        extra={"message_id": message_id, "rating": req.rating, "terfi": terfi_edildi},
    )
    return {"kaydedildi": True, "ticket_solutions_eklendi": terfi_edildi}
