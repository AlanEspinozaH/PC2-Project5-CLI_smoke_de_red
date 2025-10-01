#!/usr/bin/env bash
# src/probe_http.sh
# HTTP: pruebas de endpoints con curl, captura de códigos y latencias

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="${OUT:-"$ROOT/out"}"
RAW="${RAW:-"$OUT/raw"}"
mkdir -p "$RAW"

# Timeout para peticiones HTTP (segundos)
readonly HTTP_TIMEOUT="${HTTP_TIMEOUT:-5}"

# ============================================================================
# UTILIDADES
# ============================================================================
# Determinar esquema según puerto
determinar_esquema() {
  local port="$1"
  case "$port" in
    443) echo "https" ;;
    80)  echo "http" ;;
    *)   echo "http" ;;  # Default a HTTP
  esac
}

# ============================================================================
# SONDA HTTP PRINCIPAL
# ============================================================================
# probe_http <host> <port>
# Retorna por stdout: "HTTP_CODE,TIME_TOTAL" o "ERR,NA"
# 
# Ejemplos:
#   "200,0.234"  -> éxito
#   "404,0.123"  -> no encontrado
#   "ERR,NA"     -> error de conexión/timeout
probe_http() {
  local host="$1"
  local port="$2"
  
  # Validación de parámetros
  if [[ -z "$host" || -z "$port" ]]; then
    echo "ERR,NA"
    return 1
  fi
  
  local esquema
  esquema="$(determinar_esquema "$port")"
  
  local url="${esquema}://${host}:${port}"
  
  # Ejecutar curl con formato personalizado
  # -sS: silent pero muestra errores
  # -k: inseguro (acepta certificados autofirmados)
  # -o /dev/null: descartar body
  # -w: formato de salida
  # --max-time: timeout total
  # --connect-timeout: timeout de conexión
  local resultado
  resultado=$(curl \
    -sS \
    -k \
    -o /dev/null \
    -w "%{http_code},%{time_total}\n" \
    --max-time "$HTTP_TIMEOUT" \
    --connect-timeout 3 \
    "$url" 2>/dev/null || echo "ERR,NA")
  
  # Validar formato de salida
  if [[ "$resultado" =~ ^[0-9]{3},[0-9]+\.[0-9]+$ ]]; then
    echo "$resultado"
    return 0
  else
    echo "ERR,NA"
    return 1
  fi
}

# ============================================================================
# SONDAS HTTP EXTENDIDAS (para futura expansión)
# ============================================================================

# Captura completa de headers (para análisis)
probe_http_headers() {
  local host="$1"
  local port="$2"
  local esquema
  esquema="$(determinar_esquema "$port")"
  
  local url="${esquema}://${host}:${port}"
  local output="$RAW/http_headers_${host}_${port}.txt"
  
  curl -sS -k -I --max-time "$HTTP_TIMEOUT" "$url" > "$output" 2>&1 || {
    echo "ERROR: No se pudieron capturar headers" > "$output"
    return 1
  }
  
  return 0
}

# Verificar disponibilidad de endpoint específico
probe_http_endpoint() {
  local host="$1"
  local port="$2"
  local path="${3:-/}"
  
  local esquema
  esquema="$(determinar_esquema "$port")"
  
  local url="${esquema}://${host}:${port}${path}"
  
  # Solo código de estado
  local code
  code=$(curl \
    -sS \
    -k \
    -o /dev/null \
    -w "%{http_code}" \
    --max-time "$HTTP_TIMEOUT" \
    "$url" 2>/dev/null || echo "000")
  
  echo "$code"
}

# Análisis de códigos de estado
analizar_codigo_http() {
  local code="$1"
  
  case "$code" in
    2[0-9][0-9]) echo "OK" ;;
    3[0-9][0-9]) echo "REDIRECT" ;;
    4[0-9][0-9]) echo "CLIENT_ERROR" ;;
    5[0-9][0-9]) echo "SERVER_ERROR" ;;
    ERR|000)     echo "CONNECTION_ERROR" ;;
    *)           echo "UNKNOWN" ;;
  esac
}
