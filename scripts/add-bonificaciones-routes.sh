#!/bin/bash

# Script para agregar los endpoints de bonificaciones a las rutas de Sisbon en Kong
# Debe ejecutarse en el servidor ALB donde corre Kong

set -e

KONG_ADMIN="http://localhost:8001"

echo "======================================"
echo "Agregando rutas de bonificaciones"
echo "======================================"
echo ""

# Función para agregar path a una ruta existente
add_path_to_route() {
  local route_name=$1
  local new_path=$2

  echo "📝 Agregando path '$new_path' a ruta '$route_name'..."

  # Obtener paths actuales
  current_paths=$(curl -s "$KONG_ADMIN/routes/$route_name" | jq -r '.paths[]')

  echo "   Paths actuales:"
  echo "$current_paths" | sed 's/^/     - /'

  # Agregar nuevo path
  curl -s -X PATCH "$KONG_ADMIN/routes/$route_name" \
    --data "paths[]=$new_path" > /dev/null

  echo "   ✅ Path agregado"
  echo ""
}

# Función para verificar ruta
verify_route() {
  local route_name=$1

  echo "🔍 Verificando ruta '$route_name'..."
  paths=$(curl -s "$KONG_ADMIN/routes/$route_name" | jq -r '.paths[]')
  echo "$paths" | sed 's/^/     - /'
  echo ""
}

echo "============================================"
echo "SISBON DEV - Agregando /api-dev/sisbon/bonificaciones"
echo "============================================"
echo ""

# Verificar si ya existe
existing_paths=$(curl -s "$KONG_ADMIN/routes/sisbon-dev-route" | jq -r '.paths[]' | grep -c "sisbon/bonificaciones" || true)

if [ "$existing_paths" -eq "0" ]; then
  add_path_to_route "sisbon-dev-route" "/api-dev/sisbon/bonificaciones"
  verify_route "sisbon-dev-route"
else
  echo "⚠️  Path /api-dev/sisbon/bonificaciones ya existe en sisbon-dev-route"
  verify_route "sisbon-dev-route"
fi

echo "============================================"
echo "SISBON QA - Agregando /api-qa/sisbon/bonificaciones"
echo "============================================"
echo ""

existing_paths=$(curl -s "$KONG_ADMIN/routes/sisbon-qa-route" | jq -r '.paths[]' | grep -c "sisbon/bonificaciones" || true)

if [ "$existing_paths" -eq "0" ]; then
  add_path_to_route "sisbon-qa-route" "/api-qa/sisbon/bonificaciones"
  verify_route "sisbon-qa-route"
else
  echo "⚠️  Path /api-qa/sisbon/bonificaciones ya existe en sisbon-qa-route"
  verify_route "sisbon-qa-route"
fi

echo "============================================"
echo "SISBON PROD - Agregando /api/sisbon/bonificaciones"
echo "============================================"
echo ""

# Verificar si existe la ruta de PROD primero
if curl -s "$KONG_ADMIN/routes/sisbon-prod-route" | jq -e '.id' > /dev/null 2>&1; then
  existing_paths=$(curl -s "$KONG_ADMIN/routes/sisbon-prod-route" | jq -r '.paths[]' | grep -c "sisbon/bonificaciones" || true)

  if [ "$existing_paths" -eq "0" ]; then
    add_path_to_route "sisbon-prod-route" "/api/sisbon/bonificaciones"
    verify_route "sisbon-prod-route"
  else
    echo "⚠️  Path /api/sisbon/bonificaciones ya existe en sisbon-prod-route"
    verify_route "sisbon-prod-route"
  fi
else
  echo "⚠️  Ruta sisbon-prod-route no existe aún"
  echo "   Debe crearse primero el servicio y ruta de PROD"
  echo ""
fi

echo "======================================"
echo "✅ COMPLETADO"
echo "======================================"
echo ""
echo "Endpoints de bonificaciones disponibles:"
echo ""
echo "DEV:"
echo "  POST /api-dev/sisbon/bonificaciones/kilos-ingresados/otro-almacen"
echo "  POST /api-dev/sisbon/bonificaciones/kilos-ingresados/siop-impo"
echo "  POST /api-dev/sisbon/bonificaciones/kilos-ingresados/siop-expo"
echo "  POST /api-dev/sisbon/bonificaciones/kilos-facturados/siop-impo"
echo "  POST /api-dev/sisbon/bonificaciones/kilos-facturados/siop-expo"
echo ""
echo "QA:"
echo "  POST /api-qa/sisbon/bonificaciones/kilos-ingresados/otro-almacen"
echo "  POST /api-qa/sisbon/bonificaciones/kilos-ingresados/siop-impo"
echo "  POST /api-qa/sisbon/bonificaciones/kilos-ingresados/siop-expo"
echo "  POST /api-qa/sisbon/bonificaciones/kilos-facturados/siop-impo"
echo "  POST /api-qa/sisbon/bonificaciones/kilos-facturados/siop-expo"
echo ""
echo "PROD:"
echo "  POST /api/sisbon/bonificaciones/kilos-ingresados/otro-almacen"
echo "  POST /api/sisbon/bonificaciones/kilos-ingresados/siop-impo"
echo "  POST /api/sisbon/bonificaciones/kilos-ingresados/siop-expo"
echo "  POST /api/sisbon/bonificaciones/kilos-facturados/siop-impo"
echo "  POST /api/sisbon/bonificaciones/kilos-facturados/siop-expo"
echo ""
echo "Nota: Todos los endpoints requieren token JWT de Keycloak"
echo ""
