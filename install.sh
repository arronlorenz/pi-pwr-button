#!/bin/bash
set -euo pipefail

INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

# Packages required by the selected scripts
packages=()

install_x708_pwr() {
  echo "Installing x708-pwr.sh..."
  packages+=(gpiod)
  cp x708-pwr.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-pwr.sh"
  read -r -p "GPIO for shutdown button [5]: " shutdown
  read -r -p "GPIO for boot line [12]: " boot
  read -r -p "Minimum reboot pulse (ms) [200]: " min
  read -r -p "Maximum reboot pulse (ms) [600]: " max
  sed -i "s/^SHUTDOWN=.*/SHUTDOWN=${shutdown:-5}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^BOOT=.*/BOOT=${boot:-12}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^REBOOTPULSEMINIMUM=.*/REBOOTPULSEMINIMUM=${min:-200}/" "$INSTALL_DIR/x708-pwr.sh"
  sed -i "s/^REBOOTPULSEMAXIMUM=.*/REBOOTPULSEMAXIMUM=${max:-600}/" "$INSTALL_DIR/x708-pwr.sh"

  read -r -p "Install x708-pwr.sh as a service? [y/N] " svc
  if [[ $svc =~ ^[Yy]$ ]]; then
    cp x708-pwr.service "$SERVICE_DIR/"
    sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-pwr.sh|" "$SERVICE_DIR/x708-pwr.service"
    systemctl daemon-reload
    systemctl enable x708-pwr.service
    read -r -p "Start service now? [y/N] " startsvc
    if [[ $startsvc =~ ^[Yy]$ ]]; then
      systemctl start x708-pwr.service
    fi
  fi
}

install_x708_softsd() {
  echo "Installing x708-softsd.sh..."
  packages+=(gpiod)
  cp x708-softsd.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-softsd.sh"
  read -r -p "GPIO for power cut signal [13]: " button
  sed -i "s/^BUTTON=.*/BUTTON=${button:-13}/" "$INSTALL_DIR/x708-softsd.sh"
}

install_bat() {
  echo "Installing x708-bat.sh..."
  packages+=(gpiod i2c-tools)
  cp x708-bat.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-bat.sh"
  read -r -p "GPIO for shutdown line [13]: " pin
  sed -i "s/^PIN=.*/PIN=${pin:-13}/" "$INSTALL_DIR/x708-bat.sh"
  read -r -p "Shutdown voltage threshold [3.00]: " thr
  sed -i "s/^SHUTDOWN_VOLTAGE=.*/SHUTDOWN_VOLTAGE=${thr:-3.00}/" "$INSTALL_DIR/x708-bat.sh"
  read -r -p "Install x708-bat.sh as a service? [y/N] " svc
  if [[ $svc =~ ^[Yy]$ ]]; then
    cp x708-bat.service "$SERVICE_DIR/"
    sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-bat.sh|" "$SERVICE_DIR/x708-bat.service"
    systemctl daemon-reload
    systemctl enable x708-bat.service
    read -r -p "Start service now? [y/N] " startsvc
    if [[ $startsvc =~ ^[Yy]$ ]]; then
      systemctl start x708-bat.service
    fi
  fi
}

install_fan() {
  echo "Installing x708-fan.sh..."
  packages+=(gpiod libraspberrypi-bin)
  cp x708-fan.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-fan.sh"
  read -r -p "GPIO pin for fan control [16]: " pin
  sed -i "s/^GPIO_PIN=.*/GPIO_PIN=${pin:-16}/" "$INSTALL_DIR/x708-fan.sh"
  read -r -p "Temp to start fan (C) [55]: " on
  sed -i "s/^ON_THRESHOLD=.*/ON_THRESHOLD=${on:-55}/" "$INSTALL_DIR/x708-fan.sh"
  read -r -p "Temp to stop fan (C) [50]: " off
  sed -i "s/^OFF_THRESHOLD=.*/OFF_THRESHOLD=${off:-50}/" "$INSTALL_DIR/x708-fan.sh"
  read -r -p "Install x708-fan.sh as a service? [y/N] " svc
  if [[ $svc =~ ^[Yy]$ ]]; then
    cp x708-fan.service "$SERVICE_DIR/"
    sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-fan.sh|" "$SERVICE_DIR/x708-fan.service"
    systemctl daemon-reload
    systemctl enable x708-fan.service
    read -r -p "Start service now? [y/N] " startsvc
    if [[ $startsvc =~ ^[Yy]$ ]]; then
      systemctl start x708-fan.service
    fi
  fi
}

read -r -p "Install x708-pwr.sh (monitor buttons)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_x708_pwr
fi

read -r -p "Install x708-softsd.sh (send power-off signal)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_x708_softsd
fi

read -r -p "Install x708-bat.sh (monitor battery)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_bat
fi

read -r -p "Install x708-fan.sh (control fan)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  install_fan
fi

if (( ${#packages[@]} )); then
  mapfile -t uniq_pkgs < <(printf '%s\n' "${packages[@]}" | sort -u)
  pkg_list="${uniq_pkgs[*]}"
  read -r -p "Install required packages: $pkg_list ? [y/N] " ans
  if [[ $ans =~ ^[Yy]$ ]]; then
    apt-get update
    if ! apt-get install -y "${uniq_pkgs[@]}"; then
      echo "Failed to install dependencies with apt. Please install them manually." >&2
    fi
  fi
fi

echo "Installation complete."
