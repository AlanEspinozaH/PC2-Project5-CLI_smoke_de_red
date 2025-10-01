#!/usr/bin/env bash
# src/probe_sys.sh
# Sistema: capturas de red y bitácora (lado cliente).
# Side-effects: escribe en $RAW/*.txt, no imprime a stdout.

set -euo pipefail

# Espera que el orquestador exporte OUT/RAW; si no, define por defecto.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="${OUT:-"$ROOT/out"}"
RAW="${RAW:-"$OUT/raw"}"
mkdir -p "$RAW"

# ip addr + ip route -> raw
probe_ip() {
  ip addr show >"$RAW/ip_addr.txt"
  ip route show >"$RAW/ip_route.txt"
}

# ss -ltnp -> raw (no falla si ss no puede leer nombres de procesos)
probe_ss() {
  ss -ltnp >"$RAW/ss_listen.txt" 2>/dev/null || ss -ltn >"$RAW/ss_listen.txt" || true
}

# journalctl -p err -n 100 -> raw (si no hay systemd journal, no falla)
log_jctl() {
  journalctl -p err -n 100 --no-pager >"$RAW/journalctl_err.txt" 2>/dev/null || echo "journalctl no disponible" >"$RAW/journalctl_err.txt"
}
