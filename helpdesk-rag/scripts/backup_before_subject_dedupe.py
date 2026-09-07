"""
cleanup_sahte_agent_kopyalari.sql'in ADIM 5'i (asil silme) calistirilmadan
ONCE, silinecek subject-kopyasi ticket'lari ve bagli tum kayitlari
db/archive/<bugun>/ altina JSON olarak yedekler.

Silinecek kume, script'teki ADIM 1/2 ile BIREBIR ayni sorgu: 9 sahte agent'a
atanmis ticket'lar, subject'e gore gruplanip her grupta en eski (created_at)
kayit disinda kalanlar.
"""
import json
import os
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras

FAKE_AGENT_IDS = [
    '1f31b7ad-852a-4282-b872-9c63bb73193e', '64a4c27c-e82f-4e7a-8197-ba93b084c58c',
    '550e173f-86dc-446f-a9c4-12f9edd3fb94', 'f1bec9fc-8414-4efa-bedb-51fe100299a3',
    '574389d2-d73a-4b51-83c2-58f3c46288ce', '9b511a78-766d-4fdb-96e2-3c08f1842e75',
    '98d9db18-fc84-4221-9830-2be35f83afcd', 'f6db68a8-f3ff-4030-be4b-60e354de603d',
    'a0df5f07-ad44-4392-8d2f-d90fb70a9c5d',
]

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


def rows_as_dicts(cur):
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def json_default(o):
    if isinstance(o, datetime):
        return o.isoformat()
    return str(o)


def dump(archive_dir, table_label, query_label, rows, ts):
    fname = f"{table_label}_{ts}.json"
    path = os.path.join(archive_dir, fname)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({query_label: rows}, f, ensure_ascii=False, indent=2, default=json_default)
    print(f"  {fname}: {len(rows)} satir")
    return path


def main():
    today = datetime.now()
    archive_dir = os.path.join("db", "archive", today.strftime("%d_%m_%y"))
    os.makedirs(archive_dir, exist_ok=True)
    ts = today.strftime("%Y%m%d%H%M")

    conn = psycopg2.connect(**CONN_KWARGS)
    cur = conn.cursor()

    cur.execute(TICKET_IDS_SQL, {"fake_ids": tuple(FAKE_AGENT_IDS)})
    silinecek_ids = [r[0] for r in cur.fetchall()]
    print(f"Silinecek (subject-kopyasi) ticket sayisi: {len(silinecek_ids)}")

    if not silinecek_ids:
        print("Silinecek ticket yok, yedek alinacak bir sey yok.")
        return

    ids_tuple = tuple(silinecek_ids)

    cur.execute("SELECT * FROM tickets WHERE id IN %s", (ids_tuple,))
    dump(archive_dir, "tickets", "select * from tickets where id in (silinecek)", rows_as_dicts(cur), ts)

    cur.execute("SELECT * FROM routing_logs WHERE ticket_id IN %s", (ids_tuple,))
    dump(archive_dir, "routing_logs", "select * from routing_logs where ticket_id in (silinecek)", rows_as_dicts(cur), ts)

    cur.execute("SELECT * FROM ticket_messages WHERE ticket_id IN %s", (ids_tuple,))
    msg_rows = rows_as_dicts(cur)
    dump(archive_dir, "ticket_messages", "select * from ticket_messages where ticket_id in (silinecek)", msg_rows, ts)
    message_ids = tuple(r["id"] for r in msg_rows) or (None,)

    cur.execute("SELECT * FROM ticket_solutions WHERE ticket_id IN %s", (ids_tuple,))
    dump(archive_dir, "ticket_solutions", "select * from ticket_solutions where ticket_id in (silinecek)", rows_as_dicts(cur), ts)

    cur.execute("SELECT * FROM ai_feedbacks WHERE message_id IN %s", (message_ids,))
    dump(archive_dir, "ai_feedbacks", "select * from ai_feedbacks where message_id in (silinecek_mesajlar)", rows_as_dicts(cur), ts)

    cur.execute("SELECT * FROM message_attachments WHERE message_id IN %s", (message_ids,))
    att_rows = rows_as_dicts(cur)
    dump(archive_dir, "message_attachments", "select * from message_attachments where message_id in (silinecek_mesajlar)", att_rows, ts)
    attachment_ids = tuple(r["id"] for r in att_rows) or (None,)

    cur.execute(
        "SELECT * FROM attachment_vectors WHERE ticket_id IN %s OR attachment_id IN %s",
        (ids_tuple, attachment_ids),
    )
    dump(archive_dir, "attachment_vectors", "select * from attachment_vectors where ticket_id/attachment_id in (silinecek)", rows_as_dicts(cur), ts)

    # ayri dosya: sadece silinecek ticket ID listesi (ADIM 5'in kullandigi kumeyle
    # karsilastirma/dogrulama icin)
    id_path = os.path.join(archive_dir, f"silinecek_ticket_ids_{ts}.json")
    with open(id_path, "w", encoding="utf-8") as f:
        json.dump(silinecek_ids, f, indent=2)
    print(f"  silinecek_ticket_ids_{ts}.json: {len(silinecek_ids)} id")

    # fiziksel ek dosya yollari (bilgi amacli, ADIM 4)
    if attachment_ids != (None,):
        cur.execute("SELECT file_path FROM message_attachments WHERE id IN %s", (attachment_ids,))
        file_paths = [r[0] for r in cur.fetchall()]
        fp_path = os.path.join(archive_dir, f"silinecek_dosya_yollari_{ts}.json")
        with open(fp_path, "w", encoding="utf-8") as f:
            json.dump(file_paths, f, indent=2)
        print(f"  silinecek_dosya_yollari_{ts}.json: {len(file_paths)} yol")

    conn.close()
    print(f"\nYedek klasoru: {archive_dir}")


if __name__ == "__main__":
    main()
