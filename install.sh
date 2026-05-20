#!/usr/bin/env bash
set -e

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "❌ $ENV_EXAMPLE bulunamadı."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "✅ $ENV_EXAMPLE → $ENV_FILE kopyalandı"
else
  echo "ℹ️  $ENV_FILE mevcut, güncellenecek"
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
# Kullanıcıdan Gerekli Bilgiler
# --------------------------------------------------
read -rp "MAILRELAY_HOSTNAME (örn: mail.example.com — PTR kaydıyla eşleşmeli): " MAILRELAY_HOSTNAME

# --------------------------------------------------
# docker-compose.yml
# --------------------------------------------------
if [ ! -f "docker-compose.yml" ]; then
  cp docker-compose.production.yml docker-compose.yml
  echo "✅ docker-compose.production.yml → docker-compose.yml kopyalandı"
else
  echo "ℹ️  docker-compose.yml mevcut, atlanıyor"
fi

# --------------------------------------------------
# Docker Network
# --------------------------------------------------
NETWORK_NAME="mail-network"
if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
  echo "ℹ️  Docker network '$NETWORK_NAME' zaten mevcut"
else
  docker network create "$NETWORK_NAME"
  echo "✅ Docker network '$NETWORK_NAME' oluşturuldu"
fi

# --------------------------------------------------
# .env Güncelle
# --------------------------------------------------
set_env MAILRELAY_HOSTNAME "$MAILRELAY_HOSTNAME"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ mailrelay .env hazırlandı!"
echo "-----------------------------------------------"
echo "⚠️  PTR (reverse DNS) kaydı:"
echo "   <SUNUCU_IP> → ${MAILRELAY_HOSTNAME}"
echo "   (VPS/sunucu sağlayıcı panelinden ayarlanır)"
echo "-----------------------------------------------"
echo "📧 Domain eklemek için:"
echo "   ./scripts/add-domain.sh"
echo "-----------------------------------------------"
echo "📬 Servislerde SMTP ayarı:"
echo "   Host : mailrelay"
echo "   Port : 25"
echo "   Auth : Yok"
echo "==============================================="
