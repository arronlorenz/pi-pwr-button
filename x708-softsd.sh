#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

BUTTON=13

SLEEP=${1:-4}

re='^[0-9\.]+$'
if ! [[ $SLEEP =~ $re ]] ; then
   echo "error: sleep time not a number" >&2; exit 1
fi

echo "Your device will shut down in $SLEEP seconds..."

# Convert the delay to seconds and microseconds for gpioset
secs=${SLEEP%.*}
frac=${SLEEP#*.}
if [[ "$SLEEP" == "$secs" ]]; then
  usec=0
else
  usec=${frac}000000
  usec=${usec:0:6}
fi

gpioset --mode=time --sec="$secs" --usec="$usec" gpiochip0 $BUTTON=1
