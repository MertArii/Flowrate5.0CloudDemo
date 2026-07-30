#!/bin/bash
# Bulut Postgres'e tünel. Önce normal SSH'ı dener (hızlı); bazı ağlar
# (kurumsal/otel/misafir Wi-Fi) port 22'yi engellediği için o durumda
# otomatik olarak Google IAP tüneline (443 üzerinden, hemen hiç
# engellenmez) düşer.
#
# Kullanım:
#   ./tunel.sh          -> tüneli başlat (arka planda)
#   ./tunel.sh stop     -> tüneli durdur
#   ./tunel.sh durum    -> açık mı kontrol et

LOCAL_PORT=5433
REMOTE_HOST="mertariyurt16_gmail_com@34.118.86.1"
INSTANCE="ai-data-prep-vm"
ZONE="europe-central2-a"
KEY="$HOME/.ssh/google_compute_engine"
KNOWN_HOSTS="$HOME/.ssh/google_compute_known_hosts"

is_up() { lsof -nP -iTCP:${LOCAL_PORT} -sTCP:LISTEN >/dev/null 2>&1; }

case "$1" in
  stop)
    pkill -f "autossh.*${LOCAL_PORT}:localhost:5432" 2>/dev/null
    pkill -f "start-iap-tunnel.*${INSTANCE}" 2>/dev/null
    pkill -f "compute ssh.*${LOCAL_PORT}:localhost:5432" 2>/dev/null
    echo "Tünel durduruldu."
    ;;
  durum)
    if is_up; then echo "✅ Tünel açık (127.0.0.1:${LOCAL_PORT})"; else echo "❌ Tünel kapalı"; fi
    ;;
  *)
    pkill -f "autossh.*${LOCAL_PORT}:localhost:5432" 2>/dev/null
    pkill -f "start-iap-tunnel.*${INSTANCE}" 2>/dev/null
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
        -i "${KEY}" -L ${LOCAL_PORT}:localhost:5432 "${REMOTE_HOST}"
      sleep 3
      if is_up; then
        echo "✅ Tünel açık — normal SSH (127.0.0.1:${LOCAL_PORT})."
        exit 0
      fi
    fi

    echo "Port 22 engelli görünüyor — Google IAP üzerinden SSH'a geçiliyor (443)..."
    # start-iap-tunnel DEĞİL: o VM'in iç IP'sine bağlanır ama Postgres orada
    # sadece 127.0.0.1'e (loopback) açık. Bunun yerine IAP üzerinden SSH
    # açıp -L'i VM'in kendi loopback'i üzerinden yapıyoruz (aynı normal SSH
    # tüneli gibi çalışır, sadece taşıyıcı katman IAP/443).
    nohup gcloud compute ssh "${INSTANCE}" --zone="${ZONE}" --tunnel-through-iap \
      -- -N -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -L ${LOCAL_PORT}:localhost:5432 \
      >/tmp/iap_tunnel.log 2>&1 &
    sleep 8
    if is_up; then
      echo "✅ Tünel açık — Google IAP üzerinden SSH (127.0.0.1:${LOCAL_PORT})."
    else
      echo "❌ Açılamadı. Log: /tmp/iap_tunnel.log"
    fi
    ;;
esac
