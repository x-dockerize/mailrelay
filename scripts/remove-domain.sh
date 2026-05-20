#!/usr/bin/env bash
set -e

ENV_FILE="../.env"
DATA_DIR="../.docker/mailrelay/data"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE bulunamadı. Önce install.sh çalıştır."
  exit 1
fi

# --------------------------------------------------
# Domain Girişi
# --------------------------------------------------
CURRENT_DOMAINS=$(grep "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE" | cut -d'=' -f2-)

if [ -z "$CURRENT_DOMAINS" ]; then
  echo "ℹ️  ALLOWED_SENDER_DOMAINS listesi boş."
  exit 0
fi

echo "Mevcut domain'ler: $CURRENT_DOMAINS"
echo
read -rp "Kaldırılacak domain: " REMOVE_DOMAIN

if [ -z "$REMOVE_DOMAIN" ]; then
  echo "❌ Domain boş olamaz."
  exit 1
fi

# --------------------------------------------------
# Listede Var mı?
# --------------------------------------------------
FOUND=0
for DOMAIN in $CURRENT_DOMAINS; do
  if [ "$DOMAIN" = "$REMOVE_DOMAIN" ]; then
    FOUND=1
    break
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "❌ '$REMOVE_DOMAIN' listede bulunamadı."
  exit 1
fi

# --------------------------------------------------
# Listeden Çıkar
# --------------------------------------------------
UPDATED_DOMAINS=""
for DOMAIN in $CURRENT_DOMAINS; do
  if [ "$DOMAIN" != "$REMOVE_DOMAIN" ]; then
    if [ -z "$UPDATED_DOMAINS" ]; then
      UPDATED_DOMAINS="$DOMAIN"
    else
      UPDATED_DOMAINS="$UPDATED_DOMAINS $DOMAIN"
    fi
  fi
done

if grep -q "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE"; then
  sed -i "s|^ALLOWED_SENDER_DOMAINS=.*|ALLOWED_SENDER_DOMAINS=${UPDATED_DOMAINS}|" "$ENV_FILE"
fi

echo "✅ '$REMOVE_DOMAIN' listeden çıkarıldı."

# --------------------------------------------------
# DKIM Key Silme
# --------------------------------------------------
KEY_DIR="${DATA_DIR}/${REMOVE_DOMAIN}"
if [ -d "$KEY_DIR" ]; then
  read -rp "DKIM key'leri de silinsin mi? ($KEY_DIR) [e/H]: " DELETE_KEYS
  if [[ "$DELETE_KEYS" =~ ^[Ee]$ ]]; then
    rm -rf "$KEY_DIR"
    echo "✅ DKIM key'leri silindi."
  else
    echo "ℹ️  DKIM key'leri korundu: $KEY_DIR"
  fi
fi

# --------------------------------------------------
# Container'ı Yeniden Başlat
# --------------------------------------------------
if docker inspect mailrelay > /dev/null 2>&1; then
  echo "🔄 mailrelay container yeniden oluşturuluyor..."
  docker compose -f ../docker-compose.yml up -d mailrelay
  echo "✅ Container yeniden oluşturuldu."
else
  echo "ℹ️  mailrelay container çalışmıyor, değişiklik bir sonraki başlatmada geçerli olur."
fi

echo
echo "==============================================="
echo "✅ '$REMOVE_DOMAIN' başarıyla kaldırıldı."
echo "==============================================="
