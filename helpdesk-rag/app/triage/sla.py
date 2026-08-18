"""SLA hedef zamanlarını hesaplar (sla_policies -> tickets.*_deadline).

Seviye 1-3 süreleri takvim süresi (calendar time) olarak işletilir çünkü
PDF'te ("Bilgi Teknolojileri Olay ve Talep Yönetimi Prosedürü", 4.6) bu
seviyeler saat/dakika cinsinden ve acil müdahale gerektiriyor. Seviye 4-5
"iş günü" cinsinden (is_business_days=true) — bunlar hafta sonu hariç
sayılır. Resmi tatil takvimi şimdilik yok (basit başlangıç, gerekirse
ayrı bir tatil tablosu eklenip buraya bağlanabilir)."""
from __future__ import annotations

from datetime import datetime, timedelta


def _add_business_days(start: datetime, gun_sayisi: int) -> datetime:
    """start'tan itibaren hafta sonu hariç gun_sayisi iş günü ekler.
    Saat bileşeni korunur (mesai saati ayrımı yapılmıyor, basit sürüm)."""
    d = start
    eklenen = 0
    while eklenen < gun_sayisi:
        d += timedelta(days=1)
        if d.weekday() < 5:  # 0-4 = Pazartesi-Cuma
            eklenen += 1
    return d


def _add_target(start: datetime, hedef: timedelta | None, is_business_days: bool) -> datetime | None:
    if hedef is None:
        return None
    if is_business_days:
        return _add_business_days(start, hedef.days)
    return start + hedef


def compute_deadlines(start: datetime, policy: dict) -> dict:
    """policy: store.get_sla_policy() çıktısı (response/workaround/resolution
    hedefleri timedelta, is_business_days bool). start'tan itibaren üç
    deadline'ı hesaplayıp döner (tanımsız olanlar None)."""
    is_biz = policy["is_business_days"]
    return {
        "response_deadline": _add_target(start, policy["response_target"], is_biz),
        "workaround_deadline": _add_target(start, policy["workaround_target"], is_biz),
        "resolution_deadline": _add_target(start, policy["resolution_target"], is_biz),
    }
