#!/bin/bash
# Bulut Postgres'e kalıcı (otomatik yeniden bağlanan) SSH tüneli.
# Mac'te çalıştırılır. Bağlantı koparsa autossh kendini yeniden kurar.
#
# Kullanım:
#   ./tunel.sh          -> tüneli başlat (arka planda)
#   ./tunel.sh stop     -> tüneli durdur
#   ./tunel.sh durum    -> açık mı kontrol et

LOCAL_PORT=5433
REMOTE_HOST="mertariyurt16_gmail_com@34.118.86.1"
KEY="$HOME/.ssh/google_compute_engine"
KNOWN_HOSTS="$HOME/.ssh/google_compute_known_hosts"

case "$1" in
  stop)
    pkill -f "autossh.*${LOCAL_PORT}:localhost:5432" && echo "Tünel durduruldu." || echo "Çalışan tünel yok."
    ;;
  durum)
    if lsof -nP -iTCP:${LOCAL_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
      echo "✅ Tünel açık (127.0.0.1:${LOCAL_PORT})"
    else
      echo "❌ Tünel kapalı"
    fi
    ;;
  *)
    pkill -f "autossh.*${LOCAL_PORT}:localhost:5432" 2>/dev/null
    sleep 1
    AUTOSSH_GATETIME=0 autossh -M 0 -f -N \
      -o "ServerAliveInterval=15" \
      -o "ServerAliveCountMax=3" \
      -o "ExitOnForwardFailure=yes" \
      -o "StrictHostKeyChecking=yes" \
      -o "IdentitiesOnly=yes" \
      -o "CheckHostIP=no" \
      -o "HostKeyAlias=compute.124649961239542954" \
      -o "UserKnownHostsFile=${KNOWN_HOSTS}" \
      -i "${KEY}" \
      -L ${LOCAL_PORT}:localhost:5432 \
      "${REMOTE_HOST}"
    sleep 3
    if lsof -nP -iTCP:${LOCAL_PORT} -sTCP:LISTEN >/dev/null 2>&1; then
      echo "✅ Kalıcı tünel açıldı (127.0.0.1:${LOCAL_PORT}). Kopunca otomatik geri gelir."
    else
      echo "❌ Açılamadı — VM çalışıyor mu, IP değişmiş mi kontrol et."
    fi
    ;;
esac
