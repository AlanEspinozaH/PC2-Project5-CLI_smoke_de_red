#!/usr/bin/env bash
# src/probe_tcp.sh
# TCP & Seguridad: pruebas de puertos y SSH no-intrusivas.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="${OUT:-"$ROOT/out"}"
RAW="${RAW:-"$OUT/raw"}"
mkdir -p "$RAW"

# Retorna por stdout: "OPEN" o "CLOSED"
probe_tcp() {
  local host="$1" port="$2"
  if nc -z -w1 "$host" "$port" >/dev/null 2>&1; then
    echo "OPEN"
  else
    echo "CLOSED"
  fi
  return 0
}

# Retorna la primera línea del banner SSH o vacío
probe_ssh_banner() {
  local host="$1"
  ( echo | nc -w1 "$host" 22 2>/dev/null || true ) | head -n1 || true
}

# Si existen SSH_* hace pruebas no destructivas y loguea en raw/
probe_scp_rsync_optional() {
  local ssh_user="${SSH_USER:-}"
  local ssh_host="${SSH_HOST:-}"
  local ssh_port="${SSH_PORT:-22}"
  local ssh_key="${SSH_KEY:-}"

  [[ -n "$ssh_user" && -n "$ssh_host" ]] || return 0

  # scp: intento de envío hacia /dev/null remoto (puede fallar por permisos; se registra y se continúa)
  scp -q ${ssh_key:+-i "$ssh_key"} -P "$ssh_port" /etc/hosts "${ssh_user}@${ssh_host}:/dev/null" >>"$RAW/ssh_scp.log" 2>&1 || true

  # rsync dry-run hacia /dev/null remoto
  rsync --dry-run -e "ssh ${ssh_key:+-i "$ssh_key"} -p ${ssh_port}" /etc/hosts "${ssh_user}@${ssh_host}:/dev/null" >>"$RAW/ssh_rsync.log" 2>&1 || true
}
