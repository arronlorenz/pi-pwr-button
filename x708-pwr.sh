#!/bin/bash
set -euo pipefail

SHUTDOWN=5
REBOOTPULSEMINIMUM=200
REBOOTPULSEMAXIMUM=600
echo "$SHUTDOWN" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio$SHUTDOWN/direction
BOOT=12
echo "$BOOT" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio$BOOT/direction
echo "1" > /sys/class/gpio/gpio$BOOT/value

cleanup() {
  echo "$SHUTDOWN" > /sys/class/gpio/unexport
  echo "$BOOT" > /sys/class/gpio/unexport
}

trap cleanup EXIT

echo "Listening for power button events..."

while true; do
  shutdownSignal=$(< /sys/class/gpio/gpio"$SHUTDOWN"/value)
  if [ "$shutdownSignal" = 0 ]; then
    /bin/sleep 0.2
  else
    pulseStart=$(date +%s%N | cut -b1-13)
    while [ "$shutdownSignal" = 1 ]; do
      /bin/sleep 0.02
      if [ $(( $(date +%s%N | cut -b1-13) - pulseStart )) -gt $REBOOTPULSEMAXIMUM ]; then
        echo "Shutdown button held on GPIO $SHUTDOWN, halting Rpi..."
        sudo poweroff
        exit
      fi
      shutdownSignal=$(< /sys/class/gpio/gpio"$SHUTDOWN"/value)
    done
    if [ $(( $(date +%s%N | cut -b1-13) - pulseStart )) -gt $REBOOTPULSEMINIMUM ]; then
      echo "Reboot button pressed on GPIO $SHUTDOWN, rebooting Rpi..."
      sudo reboot
      exit
    fi
  fi
done
