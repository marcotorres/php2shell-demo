#!/usr/bin/env bash
# ============================================================================
#  demo-shell.sh — Escena de POST-EXPLOTACIÓN (dramatización para el blog)
# ----------------------------------------------------------------------------
#  Reproduce el "plano" que se ve en los videos de PHP2Shell: el momento en que
#  el atacante ya tiene shell como www-data y ejecuta comandos (id, neofetch…).
#
#  HONESTIDAD TÉCNICA — LÉELO:
#    · Aquí NO hay exploit. No reciclamos memoria, no derrotamos ASLR, no hay RCE.
#    · El "shell" que ves es REAL, pero lo abrimos con `docker exec` sobre TU
#      propio contenedor del laboratorio: es la MISMA vista que tendría un
#      atacante tras un compromiso, mostrada sin publicar ningún arma.
#    · Las líneas del "lanzamiento del exploit" son una DRAMATIZACIÓN (texto),
#      no código funcional.
#
#  Uso:    ./demo-shell.sh
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

CID="php2shell-vulnerable"
VULN_PORT="${VULN_PORT:-8091}"
SPEED="${SPEED:-1}"

if [ -t 1 ]; then
  B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
  RED=$'\e[38;5;203m'; GRN=$'\e[38;5;78m'; YEL=$'\e[38;5;221m'
  BLU=$'\e[38;5;75m'; MAG=$'\e[38;5;176m'; GRY=$'\e[38;5;245m'
else
  B=""; D=""; R=""; RED=""; GRN=""; YEL=""; BLU=""; MAG=""; GRY=""
fi
pause() { [ "$SPEED" = "0" ] || sleep "${1:-0.8}"; }

# Efecto "tecleo" de un comando y luego ejecútalo dentro del contenedor.
PROMPT="${RED}www-data@php2shell-vulnerable${R}:${BLU}/var/www/html${R}\$ "
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
run_in() { docker exec -u www-data -w /var/www/html "$CID" bash -lc "$1" 2>&1; }

# --- Preparación: asegura el contenedor vulnerable en pie --------------------
command -v docker >/dev/null 2>&1 || { echo "✗ Necesitas Docker."; exit 1; }
docker info >/dev/null 2>&1 || { echo "✗ El daemon de Docker no responde."; exit 1; }
if ! docker ps --format '{{.Names}}' | grep -q "^${CID}$"; then
  echo "▶ Levantando el servidor vulnerable…"
  docker compose up -d --build vulnerable >/dev/null 2>&1 || { echo "✗ No pude levantar el contenedor."; exit 1; }
  for i in $(seq 1 30); do [ "$(curl -sf "http://localhost:${VULN_PORT}/healthz" 2>/dev/null)" = "ok" ] && break; sleep 1; done
fi

# --- Cabecera ---------------------------------------------------------------
printf "\n${YEL}${B}  ╔══════════════════════════════════════════════════════════╗${R}\n"
printf "${YEL}${B}  ║  RECREACIÓN · el después de un PHP2Shell                  ║${R}\n"
printf "${YEL}${B}  ║  Shell real vía docker exec · sin exploit · laboratorio   ║${R}\n"
printf "${YEL}${B}  ╚══════════════════════════════════════════════════════════╝${R}\n\n"
pause 1.4

# --- El "lanzamiento": teatro, NO es código que se ejecute -------------------
printf "${GRY}# Recreación en texto de lo que haría un atacante. No se ejecuta nada.${R}\n"
printf "${D}\$ ./comprobar-objetivo.sh http://php-objetivo:%s${R}\n" "$VULN_PORT"; pause 0.9
for line in \
  "[*] Objetivo: PHP 8.4.1 · Apache mod_php" \
  "[*] Reciclando worker con un error fatal por OOM ........ ok" \
  "[*] Fugando direccion de heap via cookie PHPSESSID ...... 0xDEADBEEF (simulado)" \
  "[*] ASLR derrotado ...................................... ok (simulado)" \
  "[*] Abusando de session.upload_progress ................. ok (simulado)"; do
  printf "${GRN}%s${R}\n" "$line"; pause 0.5
done
printf "${GRN}${B}[+] Shell obtenida como www-data${R}\n\n"; pause 1.2

# --- Shell REAL (docker exec) sobre el contenedor del laboratorio -----------
type_cmd "id"
run_in "id"; echo; pause 1.0

type_cmd "hostname && uname -a"
run_in "hostname && uname -a"; echo; pause 1.0

type_cmd "neofetch"
if docker exec "$CID" bash -lc "command -v neofetch >/dev/null 2>&1"; then
  run_in "neofetch --stdout 2>/dev/null || neofetch"
else
  # Fallback si la base no trae neofetch: resumen estilo neofetch con datos reales.
  run_in '
    . /etc/os-release 2>/dev/null
    mem=$(free -h 2>/dev/null | sed -n "s/^Mem:\s*\([^ ]*\)\s*\([^ ]*\).*/\2 usados de \1/p")
    echo "   ___________        www-data@$(hostname)"
    echo "  |  php2shell |       -----------------------"
    echo "  |   >_       |       OS:     ${PRETTY_NAME:-Debian GNU/Linux}"
    echo "  |___________|       Kernel: $(uname -r)"
    echo "                      Shell:  bash"
    echo "                      PHP:    $(php -r \"echo PHP_VERSION;\" 2>/dev/null)"
    echo "                      CPU:    $(nproc) vCPU"
    echo "                      Mem:    ${mem:-n/d}"
  '
fi
echo; pause 1.4

type_cmd "ls -la /var/www/html"
run_in "ls -la /var/www/html"; echo; pause 1.0

type_cmd "head -n 3 /etc/passwd"
run_in "head -n 3 /etc/passwd"; echo; pause 1.2

# --- Cierre: bajamos el telón y recordamos para qué era todo esto ------------
printf "${YEL}${B}  Y hasta aquí la recreación.${R}\n"
printf "${GRY}──────────────────────────────────────────────────────────────${R}\n"
printf "  Un atacante de verdad solo llegaría a esta pantalla ${B}si${R} tu servidor cumpliera\n"
printf "  todas las precondiciones (justo lo que mide el triaje). El servidor ${GRN}endurecido${R}\n"
printf "  del laboratorio ni siquiera lo deja asomarse: la sonda rebota.\n\n"
printf "  ${B}La cura, en una línea:${R} actualiza PHP a la versión corregida de ${B}TU${R} rama.\n"
printf "  ${GRY}No son cuatro updates, es una por rama con soporte — mira tu 'php -v' y salta:${R}\n"
printf "  ${GRY}  8.5.x → 8.5.12 · 8.4.x → 8.4.27 · 8.3.x → 8.3.36 · 8.2.x → 8.2.35 (o superior).${R}\n"
printf "  ${GRY}  ¿En 8.1 o antes? Está en fin de vida: no hay parche, toca migrar.${R}\n"
printf "  Después, ${B}WAF delante${R} y ${B}endurece la configuración${R}.\n"
printf "  ${GRY}Lo cuento con calma aquí: https://marcotorres.pe/blog/php2shell-vulnerabilidad-php-rce${R}\n\n"
