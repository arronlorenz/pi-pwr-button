#!/bin/bash
set -euo pipefail

GPIO_CHIP="${GPIO_CHIP:-/dev/gpiochip0}"
PIN=13
CHECK_INTERVAL=60
SHUTDOWN_VOLTAGE=3.00
# Pin used for AC power loss detection. High = power lost
AC_LOSS_PIN="${AC_LOSS_PIN:-6}"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

for cmd in gpioset gpioget i2cget; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd not found; please install the gpiod and i2c-tools packages." >&2
    exit 1
  fi
done

read_word_swapped() {
  local addr=$1 reg=$2
  local raw
  raw=$(i2cget -y 1 "$addr" "$reg" w)
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

while true; do
  echo "******************"
  voltage=$(read_voltage)
  capacity=$(read_capacity)
  printf "Voltage:%5.2fV\n" "$voltage"
  printf "Battery:%5i%%\n" "$capacity"

  power_loss=$(gpioget "$GPIO_CHIP" "$AC_LOSS_PIN")
  if [[ $power_loss = 1 ]]; then
    echo "AC Power loss detected"
  else
    echo "AC Power OK"
  fi

  if (( capacity >= 100 )); then
    echo "Battery FULL"
  fi
  if (( capacity < 20 )); then
    echo "Battery Low"
  fi

  if awk -v v="$voltage" -v t="$SHUTDOWN_VOLTAGE" 'BEGIN{exit !(v < t)}'; then
    echo "Battery LOW!!!"
    echo "Shutdown in 5 seconds"
    sleep 5
    gpioset --mode=time --sec=3 "$GPIO_CHIP" "$PIN=1"
  fi

  sleep "$CHECK_INTERVAL"
done
