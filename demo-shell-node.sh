#!/usr/bin/env bash
# ============================================================================
#  demo-shell-node.sh — Escena post-explotación de Node.js (dramatización)
# ----------------------------------------------------------------------------
#  La "prima" de PHP2Shell en el runtime: el fallo del decodificador Brotli
#  (CVE-2026-111497). Recrea el "plano" del shell que se ve en los videos, con
#  una diferencia pedagógica: este contenedor corre como el usuario root, el
#  caso más común (y menos recomendable) en imágenes Node.
#
#  HONESTIDAD TÉCNICA — LÉELO:
#    · Aquí NO hay exploit ni nada que se le parezca. No se toca Brotli.
#    · El shell es REAL, pero se abre con `docker exec` sobre TU contenedor del
#      laboratorio: es la misma vista que tendría un atacante, sin arma alguna.
#    · Las líneas del "lanzamiento" son teatro (texto), no código.
#
#  Uso:    ./demo-shell-node.sh
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

CID="php2shell-node-lab"
SERVICE="node-lab"
SPEED="${SPEED:-1}"

if [ -t 1 ]; then
  B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
  RED=$'\e[38;5;203m'; GRN=$'\e[38;5;78m'; YEL=$'\e[38;5;221m'
  BLU=$'\e[38;5;75m'; MAG=$'\e[38;5;176m'; GRY=$'\e[38;5;245m'
else
  B=""; D=""; R=""; RED=""; GRN=""; YEL=""; BLU=""; MAG=""; GRY=""
fi
pause() { [ "$SPEED" = "0" ] || sleep "${1:-0.8}"; }

PROMPT="${RED}root@php2shell-node-lab${R}:${BLU}/app${R}# "
type_cmd() {
  local cmd="$1" i
  printf "%b" "$PROMPT"
  if [ "$SPEED" = "0" ]; then
    printf "%s\n" "$cmd"
  else
    for ((i=0; i<${#cmd}; i++)); do printf "%s" "${cmd:$i:1}"; sleep 0.02; done
    printf "\n"
  fi
  pause 0.3
}
run_in() { docker exec -w /app "$CID" bash -lc "$1" 2>&1; }

# --- Preparación: asegura el contenedor en pie ------------------------------
command -v docker >/dev/null 2>&1 || { echo "✗ Necesitas Docker."; exit 1; }
docker info >/dev/null 2>&1 || { echo "✗ El daemon de Docker no responde."; exit 1; }
if ! docker ps --format '{{.Names}}' | grep -q "^${CID}$"; then
  echo "▶ Levantando el servidor Node de demo…"
  docker compose --profile scenes up -d --build "$SERVICE" >/dev/null 2>&1 \
    || { echo "✗ No pude levantar el contenedor."; exit 1; }
  for i in $(seq 1 30); do docker exec "$CID" true 2>/dev/null && break; sleep 1; done
fi

# --- Cabecera ---------------------------------------------------------------
printf "\n${YEL}${B}  ╔══════════════════════════════════════════════════════════╗${R}\n"
printf "${YEL}${B}  ║  RECREACIÓN · el entorno de un Node.js comprometido      ║${R}\n"
printf "${YEL}${B}  ║  Brotli · CVE-2026-111497 · laboratorio, sin exploit     ║${R}\n"
printf "${YEL}${B}  ╚══════════════════════════════════════════════════════════╝${R}\n\n"
pause 1.4

# --- El "lanzamiento": teatro, NO es código que se ejecute -------------------
printf "${GRY}# Recreación en texto de lo que haría un atacante. No se ejecuta nada.${R}\n"
printf "${D}\$ ./comprobar-objetivo.sh http://node-objetivo:3000${R}\n"; pause 0.9
for line in \
  "[*] Objetivo: Node.js 24.5.0 (Brotli sin parchear)" \
  "[*] Comprobando la ruta de decodificacion Brotli ..... coincide" \
  "[*] Acceso conseguido (recreacion) ................... ok"; do
  printf "${GRN}%s${R}\n" "$line"; pause 0.5
done
printf "${GRN}${B}[+] Dentro. El proceso corre como root.${R}\n\n"; pause 1.2

# --- La vista REAL del entorno (docker exec) --------------------------------
type_cmd "id"
run_in "id"; echo; pause 1.0

type_cmd "node --version && hostname && uname -a"
run_in "node --version && hostname && uname -a"; echo; pause 1.0

type_cmd "neofetch"
if docker exec "$CID" bash -lc "command -v neofetch >/dev/null 2>&1"; then
  run_in "neofetch --stdout 2>/dev/null || neofetch"
else
  run_in '
    . /etc/os-release 2>/dev/null
    mem=$(free -h 2>/dev/null | sed -n "s/^Mem:\s*\([^ ]*\)\s*\([^ ]*\).*/\2 usados de \1/p")
    echo "    ____               node@$(hostname)"
    echo "   / __ \\___  ___      -----------------------"
    echo "  / / / / _ \\/ _ \\     OS:     ${PRETTY_NAME:-Debian GNU/Linux}"
    echo " / / / /  __/  __/     Kernel: $(uname -r)"
    echo "/_/ /_/\\___/\\___/      Node:   $(node --version 2>/dev/null)"
    echo "                       User:   root (uid=0)"
    echo "                       CPU:    $(nproc) vCPU"
    echo "                       Mem:    ${mem:-n/d}"
  '
fi
echo; pause 1.4

type_cmd "ls -la /app"
run_in "ls -la /app"; echo; pause 1.2

# --- Cierre: la diferencia que hace el usuario ------------------------------
printf "${YEL}${B}  Y hasta aquí la recreación.${R}\n"
printf "${GRY}──────────────────────────────────────────────────────────────${R}\n"
printf "  Fíjate en el ${RED}uid=0(root)${R} del primer comando: ese es el detalle que importa.\n"
printf "  Muchas imágenes Node corren como root por descuido, y eso convierte un fallo\n"
printf "  del runtime en un problema mucho mayor. La escena de Next (${GRN}./demo-shell-next.sh${R})\n"
printf "  enseña el otro lado: un usuario sin privilegios limita el alcance.\n\n"
printf "  ${B}La cura:${R} actualiza Node (22.23.4 / 24.22.1 / 26.12.1) ${B}y${R} añade 'USER node' a tu imagen.\n"
printf "  ${GRY}Lo cuento con calma aquí: https://marcotorres.pe/blog/php2shell-vulnerabilidad-php-rce${R}\n\n"
