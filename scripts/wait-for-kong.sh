#!/bin/sh
# Script para esperar a que Kong esté listo y luego aplicar configuraciones

KONG_ADMIN_URL="${DECK_KONG_ADDR:-http://kong:8001}"
MAX_RETRIES=60
RETRY_INTERVAL=2

echo "⏳ Esperando Kong Admin API en $KONG_ADMIN_URL..."

# Esperar a que Kong esté disponible
retry_count=0
until wget --spider -q "$KONG_ADMIN_URL/status" 2>/dev/null; do
  retry_count=$((retry_count + 1))
  if [ $retry_count -ge $MAX_RETRIES ]; then
    echo "❌ Error: Kong no respondió después de $MAX_RETRIES intentos"
    exit 1
  fi
  echo "   Intento $retry_count/$MAX_RETRIES - Kong no está listo, esperando ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "✅ Kong está listo. Aplicando configuración desde Git..."

# Aplicar configuración con deck
deck sync --kong-addr "$KONG_ADMIN_URL" --state /config/kong.yaml

if [ $? -eq 0 ]; then
  echo "🎉 Configuración aplicada exitosamente"
  exit 0
else
  echo "❌ Error al aplicar configuración"
  exit 1
fi
