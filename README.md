# pi-pwr-button

Shell helpers for the X708 UPS on the Raspberry Pi 4.

## Requirements
- `gpiod` for `gpioset`/`gpioget`
- `i2c-tools` for `i2cget`
- `libraspberrypi-bin` for `vcgencmd`

Install them with:

```bash
sudo apt-get install gpiod i2c-tools libraspberrypi-bin
```

## Installing
Run the interactive `install.sh` as root to copy the scripts to `/usr/local/bin`
and optionally enable the systemd units.

```bash
sudo ./install.sh
```

Existing services are stopped automatically so scripts can be updated.

## Scripts
- **x708-pwr.sh** – monitor the shutdown and reboot buttons.
- **x708-softsd.sh** – pulse GPIO 13 to cut power after a delay.
- **x708-shutdown-hook.sh** – optional systemd hook to call `x708-softsd.sh`
  when the system powers off.
- **x708-bat.sh** – read the battery over I²C, detect AC power loss, and shut down when low.
- **x708-fan.sh** – switch the fan between low and high speed based on CPU temperature.
- **x708-status.sh** – show battery status, fan state, AC power state, and service state.

Set `GPIO_CHIP` (default `/dev/gpiochip0`) to use a different GPIO chip.
Set `AC_LOSS_PIN` (default `6`) to change the power loss detection pin.

Most scripts need root privileges to access GPIO and I²C. Use `sudo` when
running them manually.

### Configuration
The behaviour of the scripts can be tweaked via environment variables:

- `x708-bat.sh` – `PIN` for the shutdown signal, `CHECK_INTERVAL` in seconds,
  and `SHUTDOWN_VOLTAGE` for the low-battery threshold.
- `x708-fan.sh` – `ON_THRESHOLD`, `OFF_THRESHOLD`, `SLEEP_INTERVAL`, and
  `GPIO_PIN` controlling the fan.
- `x708-status.sh` – `BUS` for the I²C bus and `GPIO_PIN` for the fan state.

## Enabling I²C
Enable the Pi's I²C interface before running `x708-bat.sh`:

```bash
sudo raspi-config  # Interface Options → I2C
```

or add `dtparam=i2c_arm=on` to `/boot/config.txt` and reboot.

## Services
Unit files are provided for each script and can be enabled by the installer or
manually using `systemctl`.

## License
MIT License. See [LICENSE](LICENSE) for details.
