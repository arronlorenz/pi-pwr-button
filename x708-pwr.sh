#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

for cmd in gpioset gpioget; do
  if ! command -v "$cmd" >/dev/null; then
    echo "$cmd not found; please install the gpiod package." >&2
    exit 1
  fi
done
SHUTDOWN=5
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
BOOT=12

# PID of the background gpioset process
boot_pid=""

cleanup() {
  if [[ -n "$boot_pid" ]] && kill -0 "$boot_pid" 2>/dev/null; then
    kill "$boot_pid"
  fi
}

# Keep the boot line asserted while running
err_file="$(mktemp)"
gpioset --mode=signal gpiochip0 "$BOOT=1" 2>"$err_file" &
boot_pid=$!

sleep 0.1
if ! kill -0 "$boot_pid" 2>/dev/null; then
  echo "Failed to start gpioset:" >&2
  cat "$err_file" >&2
  rm -f "$err_file"
  exit 1
fi
rm -f "$err_file"

trap cleanup EXIT

echo "Listening for power button events..."

while true; do
  shutdownSignal=$(gpioget gpiochip0 "$SHUTDOWN")
  if [ "$shutdownSignal" = 0 ]; then
    /bin/sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ "$shutdownSignal" = 1 ]; do
      /bin/sleep 0.02
      if [ $(( $(date +%s%N | cut -b1-13) - pulseStart )) -gt $REBOOTPULSEMAXIMUM ]; then
        echo "Shutdown button held on GPIO $SHUTDOWN, halting Rpi..."
        poweroff
        exit
      fi
      shutdownSignal=$(gpioget gpiochip0 "$SHUTDOWN")
    done
    if [ $(( $(date +%s%N | cut -b1-13) - pulseStart )) -gt $REBOOTPULSEMINIMUM ]; then
      echo "Reboot button pressed on GPIO $SHUTDOWN, rebooting Rpi..."
      reboot
      exit
    fi
  fi
done
