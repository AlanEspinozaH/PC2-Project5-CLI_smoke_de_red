#!/usr/bin/env bash
# src/smoke.sh (orquestador)
# Requiere: src/probe_sys.sh y src/probe_tcp.sh (y opcionalmente src/probe_http.sh)

set -euo pipefail

# Códigos de salida
E_GEN=1; E_NET=2; E_DNS=3; E_HTTP=4; E_CONF=5

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$ROOT/out"; RAW="$OUT/raw"
mkdir -p "$RAW"

# Variables de entorno (12-Factor)

IFS=, read -r -a HOSTS_ <<< "${HOSTS:-example.com}"
IFS=, read -r -a PORTS_ <<< "${PORTS:-80,443}"
RELEASE="${RELEASE:-dev}"
SSH_USER="${SSH_USER:-}"; SSH_HOST="${SSH_HOST:-}"; SSH_PORT="${SSH_PORT:-22}"; SSH_KEY="${SSH_KEY:-}"

# Exportar para que los módulos lo usen
export OUT RAW SSH_USER SSH_HOST SSH_PORT SSH_KEY

# Cargar módulos
source "$ROOT/src/probe_sys.sh"
source "$ROOT/src/probe_tcp.sh"
# HTTP es opcional (permite trabajo en paralelo)
if [[ -f "$ROOT/src/probe_http.sh" ]]; then
  source "$ROOT/src/probe_http.sh"
fi

# Utils
ts(){ date +%FT%T%z; }
is_ip(){ [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$1" =~ : ]]; }

# DNS: usa getent para distinguir fallo de resolución (más robusto que curl)
resolves(){
  local h="$1"; is_ip "$h" && return 0
  # DNS ok ⇒ curl -I retorna ≠6 (puede ser 7/28 etc., lo importante es distinguir 6)
  curl -sS -I --connect-timeout 1 "http://$h" >/dev/null 2>&1
  [[ $? -ne 6 ]]
}

trap 'echo "[trap] $(ts) fin de ejecución. Ver out/raw/ y out/report.csv" >&2' EXIT

# Cabecera CSV
CSV="$OUT/report.csv"
echo "timestamp,host,port,tcp,http_code,http_time" >"$CSV"

# Capturas de sistema (no afectan exit_code)
probe_ip
probe_ss
log_jctl

exit_code=0

for h in "${HOSTS_[@]}"; do
  if ! resolves "$h"; then
    # DNS: registra filas con CLOSED/NA y marca severidad E_DNS
    for p in "${PORTS_[@]}"; do
      echo "$(ts),$h,$p,CLOSED,NA,NA" >>"$CSV"
    done
    (( exit_code < E_DNS )) && exit_code=$E_DNS
    continue
  fi

  for p in "${PORTS_[@]}"; do
    tcp="$(probe_tcp "$h" "$p")"
    http="NA,NA"

    # HTTP sólo para 80/443 si existe el módulo
    if [[ "$p" == "80" || "$p" == "443" ]]; then
      if declare -F probe_http >/dev/null; then
        http="$(probe_http "$h" "$p")" || true
        if [[ "$http" == ERR,* ]]; then
          (( exit_code < E_HTTP )) && exit_code=$E_HTTP
        else
          IFS=, read -r __code __time <<<"$http"
          if [[ "${__code:-}" =~ ^[0-9]{3}$ && "$__code" -ge 400 ]]; then
            (( exit_code < E_HTTP )) && exit_code=$E_HTTP
          fi
        fi
      fi
    fi

    # TCP severidad
    if [[ "$tcp" != "OPEN" ]]; then
      (( exit_code < E_NET )) && exit_code=$E_NET
    fi

    echo "$(ts),$h,$p,$tcp,$http" >>"$CSV"
  done
done

# SSH extras si el puerto 22 está en PORTS (no afectan exit_code)
if printf '%s\n' "${PORTS_[@]}" | grep -qx '22'; then
  for h in "${HOSTS_[@]}"; do
    bnr="$(probe_ssh_banner "$h" || true)"
    [[ -n "$bnr" ]] && echo "$h,$bnr" >>"$RAW/ssh_banner.txt" || true
  done
  probe_scp_rsync_optional || true
fi

echo "Reporte: $CSV"
exit "$exit_code"
