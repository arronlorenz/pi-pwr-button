#!/usr/bin/env bash

# Bail out early if the script isn't executed with Bash. When run with a
# POSIX shell like dash, options such as `pipefail` are not supported.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script must be run with bash." >&2
  exit 1
fi

set -euo pipefail

# Allow overriding the I2C bus used for battery reads
BUS=${BUS:-1}

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

for cmd in systemctl i2cget; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd not found; please install required packages." >&2
    exit 1
  fi
done

read_word_swapped() {
  local addr=$1 reg=$2
  local raw
  raw=$(i2cget -y "$BUS" "$addr" "$reg" w)
  raw=$((raw))
  echo $(( ((raw & 0xFF) << 8) | (raw >> 8) ))
}

read_voltage() {
  local val
  val=$(read_word_swapped 0x36 0x02)
  awk -v v="$val" 'BEGIN { printf "%.2f", v * 1.25 / 1000 / 16 }'
}

read_capacity() {
  local val cap
  val=$(read_word_swapped 0x36 0x04)
  cap=$(awk -v v="$val" 'BEGIN { printf "%d", v / 256 }')
  if (( cap > 100 )); then
    cap=100
  fi
  echo "$cap"
}

show_service_status() {
  local svc=$1
  echo "$svc: $(systemctl is-active "$svc" 2>/dev/null || echo unknown)"
  echo "  Enabled: $(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)"
}

services=(x708-pwr.service x708-bat.service x708-fan.service)

echo "=== Service Status ==="
for svc in "${services[@]}"; do
  show_service_status "$svc"
done

echo
echo "=== Battery Status ==="
voltage=$(read_voltage)
capacity=$(read_capacity)
printf "Voltage: %.2f V\n" "$voltage"
printf "Capacity: %d%%\n" "$capacity"
