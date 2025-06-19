#!/bin/bash
set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

read -p "Install dependencies via apt-get? [y/N] " ans
if [[ $ans =~ ^[Yy]$ ]]; then
  apt-get update
  apt-get install -y gpiod python3-smbus2 python3-libgpiod || true
fi

install_x708_pwr() {
  echo "Installing x708-pwr.sh..."
  cp x708-pwr.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-pwr.sh"
  read -p "GPIO for shutdown button [5]: " shutdown
  read -p "GPIO for boot line [12]: " boot
  read -p "Minimum reboot pulse (ms) [200]: " min
  read -p "Maximum reboot pulse (ms) [600]: " max
  sed -i "s/^SHUTDOWN=.*/SHUTDOWN=${shutdown:-5}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^BOOT=.*/BOOT=${boot:-12}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^REBOOTPULSEMINIMUM=.*/REBOOTPULSEMINIMUM=${min:-200}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^REBOOTPULSEMAXIMUM=.*/REBOOTPULSEMAXIMUM=${max:-600}/" "$INSTALL_DIR/x708-pwr.sh"

  read -p "Install x708-pwr.sh as a service? [y/N] " svc
  if [[ $svc =~ ^[Yy]$ ]]; then
    cp x708-pwr.service "$SERVICE_DIR/"
    sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-pwr.sh|" "$SERVICE_DIR/x708-pwr.service"
    systemctl daemon-reload
    systemctl enable x708-pwr.service
    read -p "Start service now? [y/N] " startsvc
    if [[ $startsvc =~ ^[Yy]$ ]]; then
      systemctl start x708-pwr.service
    fi
  fi
}

install_x708_softsd() {
  echo "Installing x708-softsd.sh..."
  cp x708-softsd.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-softsd.sh"
  read -p "GPIO for power cut signal [13]: " button
  sed -i "s/^BUTTON=.*/BUTTON=${button:-13}/" "$INSTALL_DIR/x708-softsd.sh"
}

install_bat() {
  echo "Installing bat.py..."
  cp bat.py "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/bat.py"
  read -p "GPIO for shutdown line [13]: " pin
  sed -i "s/^PIN = .*/PIN = ${pin:-13}/" "$INSTALL_DIR/bat.py"
  read -p "Shutdown voltage threshold [3.00]: " thr
  sed -i "s/voltage < [0-9.]*:/voltage < ${thr:-3.00}:/" "$INSTALL_DIR/bat.py"
}

read -p "Install x708-pwr.sh (monitor buttons)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_x708_pwr
fi

read -p "Install x708-softsd.sh (send power-off signal)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_x708_softsd
fi

read -p "Install bat.py (monitor battery)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_bat
fi

echo "Installation complete."
