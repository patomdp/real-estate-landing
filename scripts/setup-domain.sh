#!/usr/bin/env bash
# =============================================================================
# setup-domain.sh — Conecta un subdominio (Cloudflare) a un proyecto de Vercel
# de punta a punta, sin pasos manuales.
#
# Uso:
#   CLOUDFLARE_API_TOKEN=xxx ./scripts/setup-domain.sh <subdominio.dominio.com> [project-id]
#
# Ejemplo:
#   CLOUDFLARE_API_TOKEN=xxx ./scripts/setup-domain.sh realestate.malawebs.com prj_msszlJVywKLCDdfFd32zJAFGtV0l
#
# Requisitos:
#   - Vercel CLI logueado (npx vercel login) — el token se lee de su auth.json
#   - CLOUDFLARE_API_TOKEN con permiso Zone.DNS:Edit sobre la zona del dominio
#   - curl y python en el PATH
#
# Qué hace:
#   1. Agrega el dominio al proyecto de Vercel (API POST /projects/{id}/domains)
#   2. Consulta a Vercel el CNAME esperado (API GET /domains/{domain}/config)
#   3. Crea el registro CNAME en Cloudflare con proxy DESACTIVADO (DNS only)
#   4. Espera a que Vercel verifique el dominio y emita el certificado SSL
# =============================================================================
set -euo pipefail

DOMAIN="${1:?Uso: setup-domain.sh <subdominio.dominio.com> [project-id]}"
PROJECT="${2:-prj_msszlJVywKLCDdfFd32zJAFGtV0l}"   # default: real-estate-landing
SUBDOMAIN="${DOMAIN%%.*}"                            # realestate
APEX="${DOMAIN#*.}"                                  # malawebs.com

: "${CLOUDFLARE_API_TOKEN:?Falta CLOUDFLARE_API_TOKEN (Zone.DNS:Edit)}"

# --- Token de Vercel (desde el auth.json del CLI) ---------------------------
VC_AUTH=$(ls "$HOME"/AppData/Roaming/xdg.data/com.vercel.cli/auth.json \
             "$HOME"/.local/share/com.vercel.cli/auth.json 2>/dev/null | head -1)
VC_TOKEN=$(grep -o '"token": *"[^"]*"' "$VC_AUTH" | cut -d'"' -f4)
VC_TEAM=$(curl -s "https://api.vercel.com/v2/teams" \
  -H "Authorization: Bearer $VC_TOKEN" \
  | grep -o '"id": *"team_[^"]*"' | head -1 | cut -d'"' -f4)

vc() { curl -s "https://api.vercel.com$1?teamId=$VC_TEAM" -H "Authorization: Bearer $VC_TOKEN" "${@:2}"; }
cf() { curl -s "https://api.cloudflare.com/client/v4$1" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "${@:2}"; }

# --- 1. Agregar dominio al proyecto de Vercel (idempotente) -----------------
echo "[1/4] Agregando $DOMAIN al proyecto $PROJECT en Vercel..."
vc "/v10/projects/$PROJECT/domains" -X POST -d "{\"name\":\"$DOMAIN\"}" \
  | python -c "import json,sys; d=json.load(sys.stdin); e=d.get('error'); print('   ya estaba agregado' if e and e.get('code')=='domain_already_in_use' else ('   ERROR: '+str(e) if e else '   agregado OK'))"

# --- 2. Obtener el CNAME esperado --------------------------------------------
echo "[2/4] Consultando CNAME recomendado..."
CNAME_TARGET=$(vc "/v6/domains/$DOMAIN/config" \
  | python -c "import json,sys; print(json.load(sys.stdin)['recommendedCNAME'][0]['value'].rstrip('.'))")
echo "   CNAME $SUBDOMAIN -> $CNAME_TARGET"

# --- 3. Crear el registro en Cloudflare (proxy OFF, idempotente) -------------
echo "[3/4] Creando registro DNS en Cloudflare..."
ZONE_ID=$(cf "/zones?name=$APEX" | python -c "import json,sys; print(json.load(sys.stdin)['result'][0]['id'])")
EXISTING=$(cf "/zones/$ZONE_ID/dns_records?type=CNAME&name=$DOMAIN" \
  | python -c "import json,sys; r=json.load(sys.stdin)['result']; print(r[0]['id'] if r else '')")
BODY="{\"type\":\"CNAME\",\"name\":\"$SUBDOMAIN\",\"content\":\"$CNAME_TARGET\",\"proxied\":false,\"ttl\":1,\"comment\":\"Vercel - creado por setup-domain.sh\"}"
if [ -n "$EXISTING" ]; then
  cf "/zones/$ZONE_ID/dns_records/$EXISTING" -X PUT -d "$BODY" >/dev/null && echo "   registro actualizado"
else
  cf "/zones/$ZONE_ID/dns_records" -X POST -d "$BODY" >/dev/null && echo "   registro creado"
fi

# --- 4. Esperar verificación + SSL -------------------------------------------
echo "[4/4] Esperando verificación de Vercel y emisión de SSL..."
for i in $(seq 1 30); do
  VERIFIED=$(vc "/v9/projects/$PROJECT/domains/$DOMAIN" \
    | python -c "import json,sys; print(json.load(sys.stdin).get('verified'))")
  if [ "$VERIFIED" = "True" ]; then
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" || true)
    if [ "$HTTP" = "200" ]; then
      echo "   ✅ https://$DOMAIN verificado y sirviendo (HTTP 200)"
      exit 0
    fi
    echo "   dominio verificado, esperando SSL... (HTTP $HTTP)"
  else
    echo "   esperando verificación DNS..."
  fi
  sleep 20
done
echo "   ⚠️ Timeout: revisa el estado en el dashboard de Vercel (puede tardar más en propagar)"
exit 1
