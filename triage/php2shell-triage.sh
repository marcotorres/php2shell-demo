#!/usr/bin/env bash
# ============================================================================
#  php2shell-triage.sh — ¿Está tu PHP a tiro de PHP2Shell?
#  CVE-2026-109618 / CVE-2026-109619 · https://marcotorres.pe/blog
# ----------------------------------------------------------------------------
#  Este pequeño auditor se asoma a los dos servidores del laboratorio (el flojo
#  y el endurecido) y te enseña, lado a lado, por qué uno sería un blanco y el
#  otro no. Hace cuatro cosas, nada más:
#    1) compara la versión de PHP con el parche oficial,
#    2) revisa las precondiciones que un escáner va buscando,
#    3) lanza una sonda de reconocimiento INOFENSIVA (no explota absolutamente nada),
#    4) te deja un veredicto claro y una checklist para blindarte.
#
#  Que quede dicho: aquí no hay exploit, ni payload de RCE, ni web shell. Es una
#  herramienta puramente defensiva, para mirar tu propia casa.
# ============================================================================
set -uo pipefail

VULN_URL="${VULN_URL:-http://vulnerable}"
HARD_URL="${HARD_URL:-http://hardened}"
SPEED="${SPEED:-1}"

# ---- Paleta ----------------------------------------------------------------
if [ -t 1 ]; then
  B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
  RED=$'\e[38;5;203m'; GRN=$'\e[38;5;78m'; YEL=$'\e[38;5;221m'
  BLU=$'\e[38;5;75m'; MAG=$'\e[38;5;176m'; CYA=$'\e[38;5;80m'; GRY=$'\e[38;5;245m'
else
  B=""; D=""; R=""; RED=""; GRN=""; YEL=""; BLU=""; MAG=""; CYA=""; GRY=""
fi
pause() { [ "$SPEED" = "0" ] || sleep "${1:-0.8}"; }
rule()  { printf "${GRY}%s${R}\n" "──────────────────────────────────────────────────────────────"; }

banner() {
  printf "\n${RED}${B}"
  cat <<'EOF'
   ┌─┐┬ ┬┌─┐┌─┐┌─┐┬ ┬┌─┐┬  ┬
   ├─┘├─┤├─┘┌─┘└─┐├─┤├┤ │  │
   ┴  ┴ ┴┴  └─┘└─┘┴ ┴└─┘┴─┘┴─┘  TRIAJE
EOF
  printf "${R}"
  printf "  ${B}¿Qué tan expuesto estás?${R} ${D}· auditor defensivo${R}\n"
  printf "  ${GRY}CVE-2026-109618 · CVE-2026-109619 · CVSS 9.2 · PHP 5.4 → 8.5${R}\n"
  rule
  printf "  ${YEL}Tranquilo: nada se explota aquí. Solo miramos los hosts del laboratorio.${R}\n"
  rule
  pause 1.4
}

# ---- Utilidades de versión -------------------------------------------------
fixed_for() {
  case "$1" in
    8.5.*) echo "8.5.12" ;; 8.4.*) echo "8.4.27" ;;
    8.3.*) echo "8.3.36" ;; 8.2.*) echo "8.2.35" ;;
    *)     echo "EOL"    ;;
  esac
}
# 0 (éxito) si v1 >= v2
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]; }

# ---- Auditoría de un servidor ----------------------------------------------
audit() {
  local label="$1" url="$2" color="$3"
  printf "\n${color}${B}▰▰ %s${R}  ${GRY}%s${R}\n" "$label" "$url"
  rule

  # (1) Versión y firma del servidor
  local powered ver
  powered="$(curl -s -D - -o /dev/null "$url/" | tr -d '\r' | grep -i '^X-Powered-By:' | cut -d' ' -f2-)"
  local cfg; cfg="$(curl -s "$url/triage.php")"
  ver="$(echo "$cfg" | jq -r '.php_version')"

  printf "  ${B}%s${R}\n" "Versión y firma"
  if [ -n "$powered" ]; then
    printf "    ${RED}✗${R} X-Powered-By expuesto: ${RED}%s${R}\n" "$powered"
  else
    printf "    ${GRN}✓${R} X-Powered-By oculto ${GRY}(expose_php = Off)${R}\n"
  fi
  local fixed; fixed="$(fixed_for "$ver")"
  if [ "$fixed" = "EOL" ]; then
    printf "    ${RED}✗${R} PHP %s — ${RED}${B}FIN DE VIDA${R}, sin parches\n" "$ver"
  elif ver_ge "$ver" "$fixed"; then
    printf "    ${GRN}✓${R} PHP %s — ${GRN}${B}PARCHEADO${R} (>= %s)\n" "$ver" "$fixed"
  else
    printf "    ${RED}✗${R} PHP %s — ${RED}${B}VULNERABLE${R} (parche: %s)\n" "$ver" "$fixed"
  fi
  pause 0.9

  # (2) Precondiciones
  printf "  ${B}%s${R}\n" "Precondiciones de explotación"
  prec() { # etiqueta  valor  valor_malo  nota
    local v; v="$(echo "$cfg" | jq -r ".\"$2\"")"
    if [ "$v" = "$3" ]; then
      printf "    ${RED}✗${R} %-34s ${RED}%-4s${R} ${GRY}%s${R}\n" "$1" "$v" "$4"
    else
      printf "    ${GRN}✓${R} %-34s ${GRN}%-4s${R} ${GRY}%s${R}\n" "$1" "$v" "endurecido"
    fi
    pause 0.35
  }
  prec "display_errors"                   "display_errors"                  "1" "filtra estado al atacante"
  prec "session.upload_progress.enabled"  "session.upload_progress.enabled" "1" "vía confirmada del CVE"
  prec "session.use_strict_mode"          "session.use_strict_mode"         "0" "deja fijar el PHPSESSID"
  local ml; ml="$(echo "$cfg" | jq -r '.memory_limit')"
  if [ "$ml" = "16M" ] || [ "$ml" = "32M" ] || [ "$ml" = "64M" ] || [ "$ml" = "128M" ]; then
    printf "    ${YEL}!${R} %-34s ${YEL}%-4s${R} ${GRY}%s${R}\n" "memory_limit" "$ml" "límite bajo = OOM fácil"
  else
    printf "    ${GRN}✓${R} %-34s ${GRN}%-4s${R} ${GRY}%s${R}\n" "memory_limit" "$ml" "revisado"
  fi
  pause 0.9

  # (3) La sonda: imitamos lo que haría un escáner, pero sin hacer daño.
  printf "  ${B}%s${R} ${MAG}(sonda inofensiva)${R}\n" "Reconocimiento"
  local marker; marker="MARKER_$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  local body code
  body="$(curl -s -m 8 -o /tmp/resp.$$ -w '%{http_code}' \
            -F "PHP_SESSION_UPLOAD_PROGRESS=${marker}" \
            -F 'file=@/etc/hostname' "$url/" )"
  code="$body"
  if grep -q "$marker" /tmp/resp.$$ 2>/dev/null; then
    printf "    ${RED}✗${R} HTTP %s — el servidor ${RED}REFLEJÓ${R} el marcador %s\n" "$code" "$marker"
    if grep -qi 'memory\|fatal\|allowed' /tmp/resp.$$ 2>/dev/null; then
      printf "       ${RED}↳ además filtró un Fatal error (OOM) ⇒ candidato marcado${R}\n"
    fi
  elif [ "$code" = "403" ]; then
    printf "    ${GRN}✓${R} HTTP 403 — la guardia ${GRN}cortó la sonda${R} (sin eco, sin estado)\n"
  else
    printf "    ${GRN}✓${R} HTTP %s — sin eco del marcador\n" "$code"
  fi
  rm -f /tmp/resp.$$
  pause 1.2
}

summary() {
  printf "\n${B}  EN RESUMEN${R}\n"; rule
  printf "  ${RED}%-14s${R} versión vieja, precondiciones de par en par y marcador reflejado\n" "el flojo →"
  printf "  ${GRN}%-14s${R} parcheado, superficie mínima y sonda rebotada con un 403\n" "el blindado →"
  rule
  printf "\n${GRN}${B}  Y AHORA, ¿CÓMO TE PROTEGES?${R}\n"; rule
  printf "  1. ${B}Parchea${R} PHP a la versión corregida de TU rama (8.5.12 / 8.4.27 / 8.3.36 / 8.2.35). La única cura.\n"
  printf "  2. ${B}Mete un WAF${R} delante (Cloudflare bloquea php2shell por defecto desde el 21-oct-2026).\n"
  printf "  3. ${B}Baja la superficie${R}: display_errors Off, use_strict_mode On, uploads al mínimo.\n"
  printf "  4. ${B}Vigila tus logs${R}: OOM, ráfagas de 500, PHP_SESSION_UPLOAD_PROGRESS.\n"
  rule
  printf "  ${GRY}Te lo cuento todo aquí:${R} ${B}https://marcotorres.pe/blog/php2shell-vulnerabilidad-php-rce${R}\n"
  printf "  ${GRY}\$ marcotorres.pe${R}\n\n"
}

banner
printf "  ${GRY}Primero el servidor descuidado. Fíjate en cuánto cuenta de sí mismo…${R}\n"; pause 1.2
audit "EL SERVIDOR FLOJO" "$VULN_URL" "$RED"
printf "\n  ${GRY}Ahora el mismo servidor, pero endurecido. Mira la diferencia.${R}\n"; pause 1.2
audit "EL SERVIDOR BLINDADO" "$HARD_URL" "$GRN"
summary
