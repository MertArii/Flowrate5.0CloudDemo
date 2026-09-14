import json
import urllib.request
import asyncio
from app.triage.classifier import _build_system, _get_kategoriler, _build_agac
from app.rag import store
from app.core.config import settings

async def run_debug():
    # Veritabanı ve prompt hazırlığı
    store.open_pool()
    kategoriler = _get_kategoriler()
    agac = _build_agac(store.get_category_hierarchy())
    sap_moduller = store.get_sap_modules()
    system_prompt = _build_system(kategoriler, agac, sap_moduller)

    # Ollama'ya gönderilecek raw payload
    payload = {
        "model": settings.llm_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Bilgi Teknolojileri masraf merkezinden İnsan Kaynakları masraf merkezine yapılan gider aktarımını sistem onaylamıyor. Yanlış yere yazılan masrafı kaydıramıyoruz."}
        ],
        "stream": False,
        "think": True 
    }

    # Ollama API'sine HTTP isteği (Mevcut istemcinin sınırlarına takılmamak için doğrudan istek)
    # Eğer settings'de ollama_base_url yoksa doğrudan "http://ollama:11434/api/chat" veya "http://localhost:11434/api/chat" yazabilirsin.
    ollama_url = f"{getattr(settings, 'ollama_base_url', 'http://ollama:11434')}/api/chat"
    
    req = urllib.request.Request(
        ollama_url,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )

    print(f"Ollama'ya istek atılıyor ({settings.llm_model})... Modelin düşünmesi biraz zaman alabilir.\n")
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            content = result.get('message', {}).get('content', '')
            print("--- MODELİN DÜŞÜNCE SÜRECİ VE CEVABI ---\n")
            print(content)
    except Exception as e:
        print(f"Hata oluştu: {e}")

if __name__ == "__main__":
    asyncio.run(run_debug())