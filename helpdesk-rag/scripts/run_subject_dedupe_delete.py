"""
cleanup_sahte_agent_kopyalari.sql ADIM 5 -- asil silme.
Yedek (backup_before_subject_dedupe.py) zaten alindi, dry-run (ADIM 1)
127 kalacak / 1583 silinecek / 1710 toplam olarak dogrulandi.

Tek bir DB baglantisi/transaction icinde:
  1) silinecek ticket_id kumesini yeniden hesaplar (script'teki ADIM 1/2 ile
     BIREBIR ayni sorgu -- subject'e gore grupla, en eski disindakileri al)
  2) ticket_solutions -> tickets sirasiyla siler (cascade ile routing_logs,
     ticket_messages, ai_feedbacks, message_attachments, attachment_vectors
     otomatik gider)
  3) kontrol sayilarini yazdirir
  4) hepsi beklenen degerdeyse COMMIT, degilse ROLLBACK
"""
import psycopg2

FAKE_AGENT_IDS = (
    '1f31b7ad-852a-4282-b872-9c63bb73193e', '64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94', 'f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce', '9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd', 'f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d',
)

CONN_KWARGS = dict(host="localhost", port=5433, user="helpdesk", password="demopw", dbname="helpdesk")

TICKET_IDS_SQL = """
WITH sahte_agent_ticketlari AS (
    SELECT t.id,
           row_number() OVER (
               PARTITION BY t.subject
               ORDER BY t.created_at, t.id
           ) AS rn
    FROM tickets t
    JOIN routing_logs rl ON rl.ticket_id = t.id
    WHERE rl.assigned_agent_id IN %(fake_ids)s
)
SELECT id FROM sahte_agent_ticketlari WHERE rn > 1;
"""


def main():
    conn = psycopg2.connect(**CONN_KWARGS)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute(TICKET_IDS_SQL, {"fake_ids": FAKE_AGENT_IDS})
    silinecek_ids = tuple(r[0] for r in cur.fetchall())
    print(f"Silinecek ticket sayisi (bu calismada yeniden hesaplandi): {len(silinecek_ids)}")

    if len(silinecek_ids) != 1583:
        conn.rollback()
        conn.close()
        print(f"BEKLENMEDIK SAYI ({len(silinecek_ids)} != 1583) -- islem YAPILMADI, ROLLBACK.")
        return

    # 5a) ticket_solutions once (ON DELETE SET NULL, cascade degil)
    cur.execute("DELETE FROM ticket_solutions WHERE ticket_id IN %s", (silinecek_ids,))
    print(f"ticket_solutions silinen: {cur.rowcount}")

    # 5b) tickets -> cascade ile routing_logs/ticket_messages/ai_feedbacks/
    #     message_attachments/attachment_vectors otomatik gider
    cur.execute("DELETE FROM tickets WHERE id IN %s", (silinecek_ids,))
    print(f"tickets silinen: {cur.rowcount}")

    # kontrol
    cur.execute("SELECT count(*) FROM routing_logs WHERE ticket_id IN %s", (silinecek_ids,))
    kalan_routing_logs = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM ticket_messages WHERE ticket_id IN %s", (silinecek_ids,))
    kalan_ticket_messages = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM ticket_solutions WHERE ticket_id IN %s", (silinecek_ids,))
    kalan_ticket_solutions = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM tickets WHERE id IN %s", (silinecek_ids,))
    kalan_tickets = cur.fetchone()[0]

    cur.execute(
        "SELECT count(DISTINCT t.id) FROM tickets t JOIN routing_logs rl ON rl.ticket_id = t.id "
        "WHERE rl.assigned_agent_id IN %s",
        (FAKE_AGENT_IDS,),
    )
    kalan_toplam_9_agent = cur.fetchone()[0]

    print()
    print(f"kalan_routing_logs:      {kalan_routing_logs} (0 olmali)")
    print(f"kalan_ticket_messages:   {kalan_ticket_messages} (0 olmali)")
    print(f"kalan_ticket_solutions:  {kalan_ticket_solutions} (0 olmali)")
    print(f"kalan_tickets (silinen kumeden): {kalan_tickets} (0 olmali)")
    print(f"9 sahte agent'ta TOPLAM kalan ticket: {kalan_toplam_9_agent} (127 olmali)")

    hepsi_dogru = (
        kalan_routing_logs == 0
        and kalan_ticket_messages == 0
        and kalan_ticket_solutions == 0
        and kalan_tickets == 0
        and kalan_toplam_9_agent == 127
    )

    if hepsi_dogru:
        conn.commit()
        print("\nHepsi beklenen degerde -> COMMIT edildi.")
    else:
        conn.rollback()
        print("\nBEKLENMEDIK DEGER(LER) VAR -> ROLLBACK edildi, hicbir sey degismedi.")

    conn.close()


if __name__ == "__main__":
    main()
