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
# Yardımcı Fonksiyonlar
# --------------------------------------------------
set_env() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# --------------------------------------------------
# Domain Girişi
# --------------------------------------------------
read -rp "Domain (örn: git.example.com): " NEW_DOMAIN

if [ -z "$NEW_DOMAIN" ]; then
  echo "❌ Domain boş olamaz."
  exit 1
fi

# --------------------------------------------------
# Duplicate Kontrolü
# --------------------------------------------------
CURRENT_DOMAINS=$(grep "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE" | cut -d'=' -f2-)

for DOMAIN in $CURRENT_DOMAINS; do
  if [ "$DOMAIN" = "$NEW_DOMAIN" ]; then
    echo "ℹ️  '$NEW_DOMAIN' zaten ALLOWED_SENDER_DOMAINS listesinde."
    exit 0
  fi
done

# --------------------------------------------------
# Listeye Ekle
# --------------------------------------------------
if [ -z "$CURRENT_DOMAINS" ]; then
  UPDATED_DOMAINS="$NEW_DOMAIN"
else
  UPDATED_DOMAINS="$CURRENT_DOMAINS $NEW_DOMAIN"
fi

set_env ALLOWED_SENDER_DOMAINS "$UPDATED_DOMAINS"
echo "✅ '$NEW_DOMAIN' eklendi."

# --------------------------------------------------
# Container'ı Yeniden Başlat
# --------------------------------------------------
if docker inspect mailrelay > /dev/null 2>&1; then
  echo "🔄 mailrelay container yeniden oluşturuluyor..."
  docker compose -f "$SCRIPT_DIR/../docker-compose.yml" up -d mailrelay
  echo "⏳ DKIM key üretimi bekleniyor..."
  sleep 5

  KEY_FILE="${DATA_DIR}/${NEW_DOMAIN}/mail.txt"
  ATTEMPTS=0
  while [ ! -f "$KEY_FILE" ] && [ "$ATTEMPTS" -lt 12 ]; do
    sleep 5
    ATTEMPTS=$((ATTEMPTS + 1))
  done
else
  echo "ℹ️  mailrelay container çalışmıyor. DNS kayıtları container başladıktan sonra alınabilir:"
  echo "   cat ${DATA_DIR}/${NEW_DOMAIN}/mail.txt"
fi

# --------------------------------------------------
# Sunucu IP
# --------------------------------------------------
SERVER_IPV4=$(curl -sf --max-time 5 https://v4.ip.x-app.run 2>/dev/null | tr -d '\n' || true)
SERVER_IPV6=$(curl -sf --max-time 5 https://v6.ip.x-app.run 2>/dev/null | tr -d '\n' || true)

SPF_PARTS=""
[ -n "$SERVER_IPV4" ] && SPF_PARTS="ip4:${SERVER_IPV4}"
[ -n "$SERVER_IPV6" ] && SPF_PARTS="${SPF_PARTS}${SPF_PARTS:+ }ip6:${SERVER_IPV6}"
[ -z "$SPF_PARTS"  ] && SPF_PARTS="ip4:<SUNUCU_IP>"

# --------------------------------------------------
# DNS Kayıtları
# --------------------------------------------------
echo
echo "==============================================="
echo "📋 $NEW_DOMAIN için DNS kayıtları"
echo "-----------------------------------------------"
echo "SPF:"
echo "  $NEW_DOMAIN  TXT  \"v=spf1 ${SPF_PARTS} ~all\""
echo
echo "DMARC:"
echo "  _dmarc.$NEW_DOMAIN  TXT  \"v=DMARC1; p=quarantine; rua=mailto:postmaster@$NEW_DOMAIN\""
echo
echo "DKIM:"
KEY_FILE="${DATA_DIR}/${NEW_DOMAIN}/mail.txt"
if [ -f "$KEY_FILE" ]; then
  echo "  Selector : mail"
  echo "  Record   : mail._domainkey.$NEW_DOMAIN"
  echo
  cat "$KEY_FILE"
else
  echo "  ⚠️  Key henüz üretilmedi. Container başladıktan sonra:"
  echo "  cat ${DATA_DIR}/${NEW_DOMAIN}/mail.txt"
fi
echo "==============================================="
