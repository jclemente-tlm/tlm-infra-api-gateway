#!/bin/bash

# Script para configurar JWT authentication en Kong
# Ejecutar en el servidor donde está corriendo Kong

set -e

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
KEYCLOAK_BASE_URL="${KEYCLOAK_BASE_URL:-http://alb-monitoreo-2113613529.us-east-1.elb.amazonaws.com/auth}"

echo "================================================"
echo "Configurando JWT Authentication en Kong"
echo "================================================"
echo ""
echo "Kong Admin API: $KONG_ADMIN_URL"
echo "Keycloak: $KEYCLOAK_BASE_URL"
echo ""

# Función para crear consumer
create_consumer() {
    local consumer_name=$1
    echo "→ Creando consumer: $consumer_name"

    curl -s -X POST "$KONG_ADMIN_URL/consumers" \
        --data "username=$consumer_name" \
        -o /dev/null -w "HTTP %{http_code}\n" || echo "Ya existe"
}

# Función para obtener clave pública de Keycloak
get_public_key() {
    local realm=$1
    echo "→ Obteniendo clave pública del realm: $realm"

    local public_key=$(curl -s "$KEYCLOAK_BASE_URL/realms/$realm" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['public_key'])" 2>/dev/null)

    if [ -z "$public_key" ]; then
        echo "ERROR: No se pudo obtener la clave pública del realm $realm"
        return 1
    fi

    echo "$public_key"
}

# Función para configurar JWT credential
configure_jwt_credential() {
    local consumer_name=$1
    local realm=$2
    local issuer="$KEYCLOAK_BASE_URL/realms/$realm"

    echo "→ Configurando JWT para consumer $consumer_name (realm: $realm)"

    # Obtener clave pública
    local public_key=$(get_public_key "$realm")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Formatear clave pública en formato PEM
    local rsa_public_key="-----BEGIN PUBLIC KEY-----
$public_key
-----END PUBLIC KEY-----"

    # Crear credencial JWT
    curl -s -X POST "$KONG_ADMIN_URL/consumers/$consumer_name/jwt" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "key=$issuer" \
        --data "algorithm=RS256" \
        --data-urlencode "rsa_public_key=$rsa_public_key" | \
        python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"✓ Credential ID: {d.get('id', 'ERROR')}\nIssuer: {d.get('key', 'ERROR')}\")" 2>/dev/null

    echo ""
}

# Verificar consumers
verify_consumer() {
    local consumer_name=$1
    echo "→ Verificando consumer: $consumer_name"

    curl -s "$KONG_ADMIN_URL/consumers/$consumer_name/jwt" | \
        python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"Credenciales JWT: {len(d.get('data', []))}\")" 2>/dev/null
    echo ""
}

echo "1. CREANDO CONSUMERS"
echo "--------------------"
create_consumer "tlm-mx-realm"
create_consumer "tlm-pe-realm"
echo ""

echo "2. CONFIGURANDO JWT CREDENTIALS"
echo "--------------------------------"
configure_jwt_credential "tlm-mx-realm" "tlm-mx"
configure_jwt_credential "tlm-pe-realm" "tlm-pe"

echo "3. VERIFICANDO CONFIGURACIÓN"
echo "----------------------------"
verify_consumer "tlm-mx-realm"
verify_consumer "tlm-pe-realm"

echo "================================================"
echo "✓ Configuración completada"
echo "================================================"
echo ""
echo "Para probar, obtén un token de Keycloak:"
echo ""
echo "TOKEN=\$(curl -s -X POST '$KEYCLOAK_BASE_URL/realms/tlm-mx/protocol/openid-connect/token' \\"
echo "  -d 'client_id=sisbon-mx-dev' \\"
echo "  -d 'client_secret=TU_CLIENT_SECRET' \\"
echo "  -d 'grant_type=client_credentials' | \\"
echo "  python3 -c 'import sys, json; print(json.load(sys.stdin)[\"access_token\"])')"
echo ""
echo "curl -H \"Authorization: Bearer \$TOKEN\" http://localhost:8000/api-dev/sisbon"
echo ""
