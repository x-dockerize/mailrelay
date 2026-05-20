#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
DATA_DIR="$SCRIPT_DIR/../.docker/mailrelay/data"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE bulunamadı. Önce install.sh çalıştır."
  exit 1
fi

# --------------------------------------------------
# Mevcut Domain'ler
# --------------------------------------------------
CURRENT_DOMAINS=$(grep -a "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r')

if [ -z "$CURRENT_DOMAINS" ]; then
  echo "ℹ️  ALLOWED_SENDER_DOMAINS listesi zaten boş."
  exit 0
fi

echo "Kaldırılacak domain'ler: $CURRENT_DOMAINS"
echo
read -rp "Tüm domain'ler kaldırılsın mı? [e/H]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Ee]$ ]]; then
  echo "İptal edildi."
  exit 0
fi

# --------------------------------------------------
# Listeyi Temizle
# --------------------------------------------------
if grep -qa "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE"; then
  sed -i "s|^ALLOWED_SENDER_DOMAINS=.*|ALLOWED_SENDER_DOMAINS=|" "$ENV_FILE"
fi

echo "✅ ALLOWED_SENDER_DOMAINS temizlendi."

# --------------------------------------------------
# DKIM Key'leri Silme
# --------------------------------------------------
if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
  read -rp "Tüm DKIM key'leri de silinsin mi? ($DATA_DIR) [e/H]: " DELETE_KEYS
  if [[ "$DELETE_KEYS" =~ ^[Ee]$ ]]; then
    rm -rf "${DATA_DIR:?}"/*
    echo "✅ Tüm DKIM key'leri silindi."
  else
    echo "ℹ️  DKIM key'leri korundu: $DATA_DIR"
  fi
fi

# --------------------------------------------------
# Container'ı Yeniden Başlat
# --------------------------------------------------
if docker inspect mailrelay > /dev/null 2>&1; then
  echo "🔄 mailrelay container yeniden oluşturuluyor..."
  docker compose -f "$SCRIPT_DIR/../docker-compose.yml" up -d mailrelay
  echo "✅ Container yeniden oluşturuldu."
else
  echo "ℹ️  mailrelay container çalışmıyor, değişiklik bir sonraki başlatmada geçerli olur."
fi

echo
echo "==============================================="
echo "✅ Tüm domain'ler kaldırıldı."
echo "==============================================="
