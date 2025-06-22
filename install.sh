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
# Packages that have already been installed
installed_pkgs=()

stop_service_if_running() {
  local svc=$1
  if systemctl is-active --quiet "$svc"; then
    echo "Stopping running service $svc..."
    systemctl stop "$svc"
  fi
}

install_packages() {
  if (( ${#packages[@]} )); then
    mapfile -t uniq_pkgs < <(printf '%s\n' "${packages[@]}" | sort -u)
    to_install=()
    for p in "${uniq_pkgs[@]}"; do
      if [[ " ${installed_pkgs[*]} " != *" $p "* ]]; then
        to_install+=("$p")
      fi
    done
    if (( ${#to_install[@]} )); then
      pkg_list="${to_install[*]}"
      read -r -p "Install required packages: $pkg_list ? [y/N] " ans
      if [[ $ans =~ ^[Yy]$ ]]; then
        apt-get update
        if apt-get install -y "${to_install[@]}"; then
          installed_pkgs+=("${to_install[@]}")
        else
          echo "Failed to install dependencies with apt. Please install them manually." >&2
        fi
      fi
    fi
  fi
}

install_x708_pwr() {
  echo "Installing x708-pwr.sh..."
  stop_service_if_running x708-pwr.service
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

  svc_file="$SERVICE_DIR/x708-pwr.service"
  if [[ -f "$svc_file" ]]; then
    echo "Updating service file for x708-pwr..."
    cp x708-pwr.service "$SERVICE_DIR/"
  else
    read -r -p "Install x708-pwr.sh as a service? [y/N] " svc
    if [[ ! $svc =~ ^[Yy]$ ]]; then
      return
    fi
    cp x708-pwr.service "$SERVICE_DIR/"
  fi
  sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-pwr.sh|" "$svc_file"
  systemctl daemon-reload
  systemctl enable x708-pwr.service
  read -r -p "Start service now? [y/N] " startsvc
  if [[ $startsvc =~ ^[Yy]$ ]]; then
    systemctl start x708-pwr.service
  fi
}

install_x708_softsd() {
  echo "Installing x708-softsd.sh..."
  cp x708-softsd.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-softsd.sh"
  read -r -p "GPIO for power cut signal [13]: " button
  sed -i "s/^BUTTON=.*/BUTTON=${button:-13}/" "$INSTALL_DIR/x708-softsd.sh"
}

install_bat() {
  echo "Installing x708-bat.sh..."
  stop_service_if_running x708-bat.service
  cp x708-bat.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-bat.sh"
  read -r -p "GPIO for shutdown line [13]: " pin
  sed -i "s/^PIN=.*/PIN=${pin:-13}/" "$INSTALL_DIR/x708-bat.sh"
  read -r -p "Shutdown voltage threshold [3.00]: " thr
  sed -i "s/^SHUTDOWN_VOLTAGE=.*/SHUTDOWN_VOLTAGE=${thr:-3.00}/" "$INSTALL_DIR/x708-bat.sh"
  svc_file="$SERVICE_DIR/x708-bat.service"
  if [[ -f "$svc_file" ]]; then
    echo "Updating service file for x708-bat..."
    cp x708-bat.service "$SERVICE_DIR/"
  else
    read -r -p "Install x708-bat.sh as a service? [y/N] " svc
    if [[ ! $svc =~ ^[Yy]$ ]]; then
      return
    fi
    cp x708-bat.service "$SERVICE_DIR/"
  fi
  sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-bat.sh|" "$svc_file"
  systemctl daemon-reload
  systemctl enable x708-bat.service
  read -r -p "Start service now? [y/N] " startsvc
  if [[ $startsvc =~ ^[Yy]$ ]]; then
    systemctl start x708-bat.service
  fi
}

install_fan() {
  echo "Installing x708-fan.sh..."
  stop_service_if_running x708-fan.service
  cp x708-fan.sh "$INSTALL_DIR/"
  chmod +x "$INSTALL_DIR/x708-fan.sh"
  read -r -p "GPIO pin for fan control [16]: " pin
  sed -i "s/^GPIO_PIN=.*/GPIO_PIN=${pin:-16}/" "$INSTALL_DIR/x708-fan.sh"
  read -r -p "Temp to start fan (C) [55]: " on
  sed -i "s/^ON_THRESHOLD=.*/ON_THRESHOLD=${on:-55}/" "$INSTALL_DIR/x708-fan.sh"
  read -r -p "Temp to stop fan (C) [50]: " off
  sed -i "s/^OFF_THRESHOLD=.*/OFF_THRESHOLD=${off:-50}/" "$INSTALL_DIR/x708-fan.sh"
  svc_file="$SERVICE_DIR/x708-fan.service"
  if [[ -f "$svc_file" ]]; then
    echo "Updating service file for x708-fan..."
    cp x708-fan.service "$SERVICE_DIR/"
  else
    read -r -p "Install x708-fan.sh as a service? [y/N] " svc
    if [[ ! $svc =~ ^[Yy]$ ]]; then
      return
    fi
    cp x708-fan.service "$SERVICE_DIR/"
  fi
  sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/x708-fan.sh|" "$svc_file"
  systemctl daemon-reload
  systemctl enable x708-fan.service
  read -r -p "Start service now? [y/N] " startsvc
  if [[ $startsvc =~ ^[Yy]$ ]]; then
    systemctl start x708-fan.service
  fi
}

selected_scripts=()

read -r -p "Install x708-pwr.sh (monitor buttons)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  selected_scripts+=(x708_pwr)
  packages+=(gpiod)
fi

read -r -p "Install x708-softsd.sh (send power-off signal)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  selected_scripts+=(x708_softsd)
  packages+=(gpiod)
fi

read -r -p "Install x708-bat.sh (monitor battery)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  selected_scripts+=(bat)
  packages+=(gpiod i2c-tools)
fi

read -r -p "Install x708-fan.sh (control fan)? [y/N] " resp
if [[ $resp =~ ^[Yy]$ ]]; then
  selected_scripts+=(fan)
  packages+=(gpiod libraspberrypi-bin)
fi

install_packages

for scr in "${selected_scripts[@]}"; do
  case $scr in
    x708_pwr)
      install_x708_pwr
      ;;
    x708_softsd)
      install_x708_softsd
      ;;
    bat)
      install_bat
      ;;
    fan)
      install_fan
      ;;
  esac
done

echo "Installation complete."
