#!/usr/bin/env bash
# ============================================================================
#  run.sh — El botón grande: levanta el laboratorio, corre la auditoría y
#  limpia todo al terminar. Un comando y a mirar.
#
#  Un par de variables por si las necesitas:
#     KEEP_UP=1   -> deja los contenedores en pie al acabar (para husmear)
#     VULN_PORT / HARD_PORT  -> cambia los puertos si los tuyos están ocupados
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

DC="docker compose"
VULN_PORT="${VULN_PORT:-8091}"
HARD_PORT="${HARD_PORT:-8092}"
export VULN_PORT HARD_PORT
command -v docker >/dev/null 2>&1 || { echo "✗ Oye, necesito Docker instalado y corriendo para esto."; exit 1; }
docker info >/dev/null 2>&1 || { echo "✗ Docker no responde. ¿Está Docker Desktop abierto?"; exit 1; }

cleanup() {
  if [ "${KEEP_UP:-0}" = "1" ]; then
    echo; echo "▶ KEEP_UP=1 — te dejo los contenedores en pie. Cuando acabes: $DC down"
    return
  fi
  echo; echo "▶ Recogemos: desmontando el laboratorio…"
  $DC down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "▶ Montando las imágenes… (la primera vez tarda un poco, baja PHP)"
if ! $DC build vulnerable hardened; then
  echo; echo "✗ Algo falló construyendo las imágenes. El error de arriba te dice qué."
  exit 1
fi

echo; echo "▶ Encendiendo los dos servidores…"
if ! $DC up -d vulnerable hardened; then
  echo; echo "✗ No arrancaron. Lo más típico: un puerto ocupado ($VULN_PORT / $HARD_PORT)."
  echo "  Míralo con 'docker ps', o relanza con otros: VULN_PORT=9001 HARD_PORT=9002 ./run.sh"
  exit 1
fi

echo "▶ Esperando a que respondan…"
ok=0
for i in $(seq 1 40); do
  v=$(curl -sf "http://localhost:${VULN_PORT}/healthz" 2>/dev/null || true)
  h=$(curl -sf "http://localhost:${HARD_PORT}/healthz" 2>/dev/null || true)
  if [ "$v" = "ok" ] && [ "$h" = "ok" ]; then ok=1; break; fi
  sleep 1
done
if [ "$ok" != "1" ]; then
  echo "✗ Tardaron demasiado en levantar. Te dejo los últimos logs por si acaso:"
  $DC logs --tail 30 vulnerable hardened || true
  exit 1
fi
echo "  listos → flojo: http://localhost:${VULN_PORT}   ·   blindado: http://localhost:${HARD_PORT}"

echo; echo "▶ Y ahora, la auditoría…"; echo
$DC run --rm triage
