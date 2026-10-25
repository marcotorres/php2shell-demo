#!/usr/bin/env bash
# ============================================================================
#  demo-shell-next.sh — Escena post-explotación de Next.js (dramatización)
# ----------------------------------------------------------------------------
#  La "prima" de PHP2Shell en el framework: el fallo de sharp al procesar SVG
#  (CVE-2026-96889). Recrea el "plano" del shell, con el contraste que importa:
#  este despliegue corre como el usuario `nextjs` (sin privilegios), tal y como
#  recomienda la guía oficial. El mismo tipo de fallo hace aquí mucho menos daño.
#
#  HONESTIDAD TÉCNICA — LÉELO:
#    · Aquí NO hay exploit ni nada que se le parezca. No se toca sharp ni SVG.
#    · El shell es REAL, pero se abre con `docker exec` sobre TU contenedor del
#      laboratorio: es la misma vista que tendría un atacante, sin arma alguna.
#    · Las líneas del "lanzamiento" son teatro (texto), no código.
#
#  Uso:    ./demo-shell-next.sh
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

CID="php2shell-next-lab"
SERVICE="next-lab"
SPEED="${SPEED:-1}"

if [ -t 1 ]; then
  B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
  RED=$'\e[38;5;203m'; GRN=$'\e[38;5;78m'; YEL=$'\e[38;5;221m'
  BLU=$'\e[38;5;75m'; MAG=$'\e[38;5;176m'; GRY=$'\e[38;5;245m'
else
  B=""; D=""; R=""; RED=""; GRN=""; YEL=""; BLU=""; MAG=""; GRY=""
fi
pause() { [ "$SPEED" = "0" ] || sleep "${1:-0.8}"; }

# Prompt de usuario normal: '$', no '#'. Y el nombre lo dice todo: nextjs.
PROMPT="${GRN}nextjs@php2shell-next-lab${R}:${BLU}/app${R}\$ "
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
# Sin -u: el contenedor define USER nextjs, así que docker exec entra como nextjs.
run_in() { docker exec -w /app "$CID" bash -lc "$1" 2>&1; }

# --- Preparación: asegura el contenedor en pie ------------------------------
command -v docker >/dev/null 2>&1 || { echo "✗ Necesitas Docker."; exit 1; }
docker info >/dev/null 2>&1 || { echo "✗ El daemon de Docker no responde."; exit 1; }
if ! docker ps --format '{{.Names}}' | grep -q "^${CID}$"; then
  echo "▶ Levantando el despliegue Next de demo… (la primera vez compila, tarda un poco)"
  docker compose --profile scenes up -d --build "$SERVICE" >/dev/null 2>&1 \
    || { echo "✗ No pude levantar el contenedor."; exit 1; }
  for i in $(seq 1 40); do docker exec "$CID" true 2>/dev/null && break; sleep 1; done
fi

# --- Cabecera ---------------------------------------------------------------
printf "\n${YEL}${B}  ╔══════════════════════════════════════════════════════════╗${R}\n"
printf "${YEL}${B}  ║  RECREACIÓN · el entorno de un Next.js comprometido      ║${R}\n"
printf "${YEL}${B}  ║  sharp/SVG · CVE-2026-96889 · laboratorio, sin exploit   ║${R}\n"
printf "${YEL}${B}  ╚══════════════════════════════════════════════════════════╝${R}\n\n"
pause 1.4

# --- El "lanzamiento": teatro, NO es código que se ejecute -------------------
printf "${GRY}# Recreación en texto de lo que haría un atacante. No se ejecuta nada.${R}\n"
printf "${D}\$ ./comprobar-objetivo.sh http://next-objetivo:3000${R}\n"; pause 0.9
for line in \
  "[*] Objetivo: Next.js 14.2.33 (sharp sin parchear)" \
  "[*] Comprobando la ruta de optimizacion de imagenes ... coincide" \
  "[*] Acceso conseguido (recreacion) .................... ok"; do
  printf "${GRN}%s${R}\n" "$line"; pause 0.5
done
printf "${GRN}${B}[+] Dentro. El proceso corre como nextjs (sin privilegios).${R}\n\n"; pause 1.2

# --- La vista REAL del entorno (docker exec) --------------------------------
type_cmd "id"
run_in "id"; echo; pause 1.0

type_cmd "node --version && npx next --version && hostname"
run_in "node --version && (npx --no-install next --version 2>/dev/null || echo 'next: ver package.json') && hostname"; echo; pause 1.0

type_cmd "neofetch"
if docker exec "$CID" bash -lc "command -v neofetch >/dev/null 2>&1"; then
  run_in "neofetch --stdout 2>/dev/null || neofetch"
else
  run_in '
    . /etc/os-release 2>/dev/null
    nextv=$(node -p "require(\"/app/node_modules/next/package.json\").version" 2>/dev/null)
    mem=$(free -h 2>/dev/null | sed -n "s/^Mem:\s*\([^ ]*\)\s*\([^ ]*\).*/\2 usados de \1/p")
    echo "      ___            nextjs@$(hostname)"
    echo "     /   \\           -----------------------"
    echo "    / /\\  \\          OS:     ${PRETTY_NAME:-Debian GNU/Linux}"
    echo "   / /  \\  \\         Kernel: $(uname -r)"
    echo "  /_/    \\__\\        Node:   $(node --version 2>/dev/null)"
    echo "   ▲ Next.js         Next:   ${nextv:-?}"
    echo "                     User:   nextjs (uid=1001)"
    echo "                     Mem:    ${mem:-n/d}"
  '
fi
echo; pause 1.4

type_cmd "ls -la /app"
run_in "ls -la /app"; echo; pause 1.0

# Muestra, sin tocar nada sensible, que este usuario NO puede escribir fuera de lo suyo.
type_cmd "touch /etc/prueba 2>&1 || echo 'denegado: nextjs no tiene permiso'"
run_in "touch /etc/prueba 2>&1 || echo 'denegado: nextjs no tiene permiso'"; echo; pause 1.2

# --- Cierre: por qué esta escena da menos miedo -----------------------------
printf "${YEL}${B}  Y hasta aquí la recreación.${R}\n"
printf "${GRY}──────────────────────────────────────────────────────────────${R}\n"
printf "  Fíjate en el ${GRN}uid=1001(nextjs)${R} y en que no pudo escribir en /etc. El fallo de\n"
printf "  sharp es tan serio como el de Node, pero aquí el despliegue sigue la guía oficial\n"
printf "  y corre con un usuario sin privilegios: el alcance de un compromiso queda acotado.\n"
printf "  Compáralo con ${RED}./demo-shell-node.sh${R}, que corría como root.\n\n"
printf "  ${B}La cura:${R} actualiza Next (15.5.28 / 16.4.1) ${B}y${R} despliega siempre con 'USER nextjs'.\n"
printf "  ${GRY}Lo cuento con calma aquí: https://marcotorres.pe/blog/php2shell-vulnerabilidad-php-rce${R}\n\n"
