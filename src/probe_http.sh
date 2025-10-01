#!/usr/bin/env bash
# src/probe_http.sh
# HTTP & Métricas: curl (HTTP/HTTPS), códigos y tiempos, redirects/TLS (-k)
# Contrato: probe_http <host> <port> -> "HTTP_CODE,TIME_MS" | "ERR,NA"
# Regla: 443 -> https:// ; 80 -> http:// ; otros: no se llama desde el orquestador.

set -euo pipefail

probe_http() {
  local host="$1" port="$2" scheme url
  case "$port" in
    80)  scheme="http" ;;
    443) scheme="https" ;;
    *)   echo "ERR,NA"; return 0 ;;
  esac

  url="${scheme}://${host}/"

  local code time_s out
  if [[ "$scheme" == "https" ]]; then
    # -k ignora problemas de certificado para propósitos educativos (sin PKI)
    out="$(LC_ALL=C curl -sS -k -o /dev/null --connect-timeout 2 --max-time 5 -w "%{http_code},%{time_total}" "$url")" || {
      echo "ERR,NA"; return 0;
    }
  else
    out="$(LC_ALL=C curl -sS    -o /dev/null --connect-timeout 2 --max-time 5 -w "%{http_code},%{time_total}" "$url")" || {
      echo "ERR,NA"; return 0;
    }
  fi

  IFS=, read -r code time_s <<<"$out"


  # A ms enteros, ancho fijo de 6 dígitos para idempotencia de tamaño
  # 0.123s -> 000123 ; 1.234s -> 001234
  local time_ms
  time_ms="$(LC_ALL=C awk -v t="$time_s" 'BEGIN{ printf "%06d", int(t*1000 + 0.5) }')"
  if [[ "$code" =~ ^[0-9]{3}$ ]]; then
    echo "${code},${time_ms}"
  else
    echo "ERR,NA"
  fi
}
