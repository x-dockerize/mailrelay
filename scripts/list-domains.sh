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
# Domain Listesi
# --------------------------------------------------
CURRENT_DOMAINS=$(grep -a "^ALLOWED_SENDER_DOMAINS=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r')

if [ -z "$CURRENT_DOMAINS" ]; then
  echo "ℹ️  Kayıtlı domain yok."
  exit 0
fi

# --------------------------------------------------
# Yardımcı: Domain Yapılandırmasını Göster
# --------------------------------------------------
show_domain() {
  local DOMAIN="$1"

  SERVER_IPV4=$(curl -sf --max-time 5 https://v4.ip.x-app.run 2>/dev/null | tr -d '\n' || true)
  SERVER_IPV6=$(curl -sf --max-time 5 https://v6.ip.x-app.run 2>/dev/null | tr -d '\n' || true)

  SPF_PARTS=""
  [ -n "$SERVER_IPV4" ] && SPF_PARTS="ip4:${SERVER_IPV4}"
  [ -n "$SERVER_IPV6" ] && SPF_PARTS="${SPF_PARTS}${SPF_PARTS:+ }ip6:${SERVER_IPV6}"
  [ -z "$SPF_PARTS"  ] && SPF_PARTS="ip4:<SUNUCU_IP>"

  DMARC_RUA=$(grep -a "^DMARC_RUA=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r')
  DMARC_RECORD="v=DMARC1; p=quarantine"
  [ -n "$DMARC_RUA" ] && DMARC_RECORD="${DMARC_RECORD}; rua=mailto:${DMARC_RUA}"

  echo
  echo "==============================================="
  echo "📋 $DOMAIN"
  echo "-----------------------------------------------"
  echo "SPF:"
  echo "  $DOMAIN  TXT  \"v=spf1 ${SPF_PARTS} ~all\""
  echo
  echo "DMARC:"
  echo "  _dmarc.$DOMAIN  TXT  \"${DMARC_RECORD}\""
  echo
  echo "DKIM:"
  KEY_FILE="${DATA_DIR}/${DOMAIN}.txt"
  if [ -f "$KEY_FILE" ]; then
    DKIM_VALUE=$(grep -oE '"[^"]*"' "$KEY_FILE" | tr -d '"' | tr -d '\n')
    echo "  mail._domainkey.$DOMAIN  TXT  \"${DKIM_VALUE}\""
  else
    echo "  ⚠️  Key henüz üretilmedi."
    echo "  cat ${DATA_DIR}/${DOMAIN}.txt"
  fi
  echo "==============================================="
}

# --------------------------------------------------
# Seçim Menüsü
# --------------------------------------------------
echo "Kayıtlı domain'ler:"
echo

# shellcheck disable=SC2206
DOMAIN_ARRAY=($CURRENT_DOMAINS)

PS3=$'\nDomain seç [1-'${#DOMAIN_ARRAY[@]}'] — q: çıkış): '
select DOMAIN in "${DOMAIN_ARRAY[@]}"; do
  [ "$REPLY" = "q" ] && break
  [ -z "$DOMAIN"  ] && echo "Geçersiz seçim." && continue
  show_domain "$DOMAIN"
done
