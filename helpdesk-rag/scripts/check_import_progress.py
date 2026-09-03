"""import_sla_dataset.py'nin ilerlemesini DB'den doğrudan kontrol eder
(log dosyasının arabelleğe alınmış olmasından bağımsız, güvenilir sayım)."""
from app.rag import store

store.open_pool()
with store._connect() as conn, conn.cursor() as cur:
    cur.execute(
        "SELECT count(*) FROM routing_logs WHERE decision_factors->>'kaynak' = 'toplu_import_sla_dataset'"
    )
    islenen = cur.fetchone()[0]

    cur.execute(
        "SELECT count(*) FROM ticket_solutions WHERE metadata->>'kaynak' = 'orijinal'"
    )
    cozum_sayisi = cur.fetchone()[0]

    cur.execute(
        """
        SELECT count(*) FROM ticket_solutions ts
        LEFT JOIN tickets t ON t.id = ts.ticket_id
        WHERE ts.metadata->>'kaynak' = 'orijinal' AND t.id IS NULL
        """
    )
    yetim_solutions = cur.fetchone()[0]

    cur.execute(
        """
        SELECT t.id, t.ticket_number, t.status, t.subject, t.created_at
        FROM tickets t
        JOIN routing_logs rl ON rl.ticket_id = t.id
        WHERE rl.decision_factors->>'kaynak' = 'toplu_import_sla_dataset'
        ORDER BY t.created_at DESC
        LIMIT 5
        """
    )
    ornekler = cur.fetchall()

print(f"İşlenen ticket (routing_logs): {islenen}")
print(f"Eklenen ticket_solutions: {cozum_sayisi}")
print(f"Sahipsiz (tickets'ta karşılığı olmayan) ticket_solutions: {yetim_solutions}")
print("Son eklenen ticket'lardan örnekler (id, no, status, konu, tarih):")
for row in ornekler:
    print(" ", row)
store.close_pool()
