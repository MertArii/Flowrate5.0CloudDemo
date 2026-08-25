#!/bin/bash
# Bulut VM'e tünel: Postgres (5433->5432) VE API (8000->8000) birlikte.
# Önce normal SSH'ı dener (hızlı); bazı ağlar (kurumsal/otel/misafir Wi-Fi)
# port 22'yi engellediği için o durumda otomatik olarak Google IAP tüneline
# (443 üzerinden, hemen hiç engellenmez) düşer.
#
# Kullanım:
#   ./tunel.sh          -> her iki tüneli başlat (arka planda)
#   ./tunel.sh stop     -> tümünü durdur
#   ./tunel.sh durum    -> ikisi de açık mı kontrol et

DB_PORT=5433
API_PORT=8000
REMOTE_HOST="mertariyurt16_gmail_com@34.118.86.1"
INSTANCE="ai-data-prep-vm"
ZONE="europe-central2-a"
KEY="$HOME/.ssh/google_compute_engine"
KNOWN_HOSTS="$HOME/.ssh/google_compute_known_hosts"

is_up() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

case "$1" in
  stop)
    pkill -f "${DB_PORT}:localhost:5432" 2>/dev/null
    pkill -f "${API_PORT}:localhost:8000" 2>/dev/null
    pkill -f "start-iap-tunnel" 2>/dev/null
    echo "Tüneller durduruldu."
    ;;
  durum)
    if is_up ${DB_PORT}; then echo "✅ DB tüneli açık (127.0.0.1:${DB_PORT})"; else echo "❌ DB tüneli kapalı"; fi
    if is_up ${API_PORT}; then echo "✅ API tüneli açık (127.0.0.1:${API_PORT})"; else echo "❌ API tüneli kapalı"; fi
    ;;
  *)
    pkill -f "${DB_PORT}:localhost:5432" 2>/dev/null
    pkill -f "${API_PORT}:localhost:8000" 2>/dev/null
    pkill -f "start-iap-tunnel" 2>/dev/null
    sleep 1


    echo "Normal SSH deneniyor (port 22)..."
    if ssh -o ConnectTimeout=6 -o BatchMode=yes \
        -i "${KEY}" \
        -o "HostKeyAlias=compute.124649961239542954" \
        -o "UserKnownHostsFile=${KNOWN_HOSTS}" \
        -o "CheckHostIP=no" -o "IdentitiesOnly=yes" \
        -o "StrictHostKeyChecking=yes" \
        "${REMOTE_HOST}" true 2>/dev/null; then
      AUTOSSH_GATETIME=0 autossh -M 0 -f -N \
        -o "ServerAliveInterval=15" -o "ServerAliveCountMax=3" \
        -o "ExitOnForwardFailure=yes" -o "StrictHostKeyChecking=yes" \
        -o "IdentitiesOnly=yes" -o "CheckHostIP=no" \
        -o "HostKeyAlias=compute.124649961239542954" \
        -o "UserKnownHostsFile=${KNOWN_HOSTS}" \
        -i "${KEY}" \
        -L ${DB_PORT}:localhost:5432 \
        -L ${API_PORT}:localhost:8000 \
        "${REMOTE_HOST}"
      sleep 3
      if is_up ${DB_PORT} && is_up ${API_PORT}; then
        echo "✅ Tüneller açık — normal SSH (127.0.0.1:${DB_PORT} DB, 127.0.0.1:${API_PORT} API)."
        exit 0
      fi
    fi

    echo "Port 22 engelli görünüyor — Google IAP üzerinden SSH'a geçiliyor (443)..."
    nohup gcloud compute ssh "${INSTANCE}" --zone="${ZONE}" --tunnel-through-iap \
      -- -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -L ${DB_PORT}:localhost:5432 \
      -L ${API_PORT}:localhost:8000 \
      >/tmp/iap_tunnel.log 2>&1 &
    sleep 8
    if is_up ${DB_PORT} && is_up ${API_PORT}; then
      echo "✅ Tüneller açık — Google IAP üzerinden SSH (127.0.0.1:${DB_PORT} DB, 127.0.0.1:${API_PORT} API)."
    else
      echo "❌ Açılamadı (ya da kısmen). Log: /tmp/iap_tunnel.log"
      is_up ${DB_PORT} && echo "  DB tüneli açık" || echo "  DB tüneli kapalı"
      is_up ${API_PORT} && echo "  API tüneli açık" || echo "  API tüneli kapalı"
    fi
    ;;
esac
