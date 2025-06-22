#!/bin/bash
set -euo pipefail

# Allow overriding the GPIO chip path.
GPIO_CHIP="${GPIO_CHIP:-/dev/gpiochip0}"

ON_THRESHOLD=55  # degrees Celsius
OFF_THRESHOLD=50
SLEEP_INTERVAL=5
GPIO_PIN=16

if [[ $OFF_THRESHOLD -ge $ON_THRESHOLD ]]; then
  echo "OFF_THRESHOLD must be less than ON_THRESHOLD" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

for cmd in gpioset vcgencmd; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd not found; please install the gpiod and libraspberrypi-bin packages." >&2
    exit 1
  fi
done

fan_pid=""

cleanup() {
  if [[ -n "$fan_pid" ]] && kill -0 "$fan_pid" 2>/dev/null; then
    kill "$fan_pid"
  fi
}
trap cleanup EXIT

start_fan() {
  cleanup
  gpioset --mode=signal "$GPIO_CHIP" "$GPIO_PIN=1" &
  fan_pid=$!
  state=1
  logger -t x708-fan "Fan turned on"
}

stop_fan() {
  cleanup
  gpioset --mode=signal "$GPIO_CHIP" "$GPIO_PIN=0" &
  fan_pid=$!
  state=0
  logger -t x708-fan "Fan turned off"
}

state=0
stop_fan

while true; do
  temp=$(vcgencmd measure_temp | awk -F"[='C]" '{print $2}')
  temp_int=$(printf '%.0f' "$temp")

  if (( temp_int > ON_THRESHOLD && state == 0 )); then
    start_fan
  elif (( temp_int < OFF_THRESHOLD && state == 1 )); then
    stop_fan
  fi

  sleep "$SLEEP_INTERVAL"
done
