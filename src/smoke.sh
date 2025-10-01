#!/usr/bin/env bash

set -euo pipefail



# Códigos de salida (documentados en README):

E_GEN=1; E_NET=2; E_DNS=3; E_HTTP=4; E_CONF=5



ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

OUT="$ROOT/out"; RAW="$OUT/raw"

mkdir -p "$RAW"



# Parse de entorno (12-Factor III)

IFS=, read -r -a HOSTS_ <<< "${HOSTS:-example.com}"

IFS=, read -r -a PORTS_ <<< "${PORTS:-80,443,22}"

SSH_USER="${SSH_USER:-}"; SSH_HOST="${SSH_HOST:-}"; SSH_PORT="${SSH_PORT:-22}"

RELEASE="${RELEASE:-dev}"



# Utilidades

ts(){ date +%FT%T%z; }

scheme_for_port(){ [[ "$1" == "443" ]] && echo "https" || echo "http"; }



# Capturas "crudas" para bitácora (ip/ss/journalctl)

probe_ip(){  ip addr show >"$RAW/ip_addr.txt"; ip route show >"$RAW/ip_route.txt"; }

probe_ss(){  ss -ltnp      >"$RAW/ss_listen.txt" || true; }

log_jctl(){  journalctl -p err -n 100 --no-pager >"$RAW/journalctl_err.txt" || true; }



# Probes

probe_tcp(){ nc -zv -w1 "$1" "$2" >/dev/null 2>&1 && echo "OPEN" || echo "CLOSED"; }

probe_http(){

  local host="$1" port="$2" sch; sch="$(scheme_for_port "$port")"

  curl -sS -k -o /dev/null -w "%{http_code},%{time_total}\n" "${sch}://${host}:${port}" || echo "ERR,NA"

}

probe_ssh_banner(){

  (echo | nc -w1 "$1" 22 2>/dev/null || true) | head -n1

}

probe_scp_rsync_optional(){

  [[ -n "$SSH_USER" && -n "$SSH_HOST" ]] || return 0

  scp -q ${SSH_KEY:+-i "$SSH_KEY"} -P "${SSH_PORT}" /etc/hosts "${SSH_USER}@${SSH_HOST}:/dev/null" 2>>"$RAW/ssh_scp.log" || true

  rsync --dry-run -e "ssh ${SSH_KEY:+-i "$SSH_KEY"} -p ${SSH_PORT}" /etc/hosts "${SSH_USER}@${SSH_HOST}:/dev/null" >>"$RAW/ssh_rsync.log" 2>&1 || true

}



# Orquestación

trap 'echo "[trap] $(ts) fin de ejecución. Ver out/raw/ y out/report.csv" >&2' EXIT



echo "timestamp,host,port,tcp,http_code,http_time" >"$OUT/report.csv"

probe_ip; probe_ss



exit_code=0

for h in "${HOSTS_[@]}"; do

  for p in "${PORTS_[@]}"; do

    tcp="$(probe_tcp "$h" "$p")"

    http="NA,NA"

    if [[ "$p" == "80" || "$p" == "443" ]]; then

      http="$(probe_http "$h" "$p")"

      [[ "$http" == ERR,* ]] && exit_code=$(( exit_code < E_HTTP ? E_HTTP : exit_code ))

    fi

    [[ "$tcp" == "CLOSED" ]] && exit_code=$(( exit_code < E_NET ? E_NET : exit_code ))

    echo "$(ts),$h,$p,$tcp,$http" >>"$OUT/report.csv"

  done

done



if printf '%s\n' "${PORTS_[@]}" | grep -q '^22$'; then

  for h in "${HOSTS_[@]}"; do

    bnr="$(probe_ssh_banner "$h" || true)"

    [[ -n "$bnr" ]] && echo "$h,$bnr" >>"$RAW/ssh_banner.txt" || true

  done

  probe_scp_rsync_optional || true

fi



log_jctl

echo "Reporte: $OUT/report.csv"

exit "$exit_code"

