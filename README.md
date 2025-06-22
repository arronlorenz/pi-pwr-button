# pi-pwr-button

Utilities for handling power events on the X708 UPS for the Raspberry Pi 4.

## Dependencies

- `gpiod` for the `gpioset`/`gpioget` tools
- Python 3 with the `smbus2` and `gpiod` packages (the `python3-smbus2` package may not be
  available on all distributions)

The scripts check that these tools are installed and will exit with an error if
they are missing.

Install them on a Debian-based system with:

```bash
sudo apt-get install gpiod python3-libgpiod python3-smbus2
```

If the `python3-smbus2` package is missing you can install `smbus2` with pip.
Use the `--break-system-packages` flag only when your pip version supports it:

```bash
if python3 -m pip install --help | grep -q -- --break-system-packages; then
  python3 -m pip install smbus2 --break-system-packages
else
  python3 -m pip install smbus2
fi
```

If `python3-libgpiod` is not available,
install the `gpiod` Python package with pip:

```bash
python3 -m pip install gpiod
```

## Installation script

The repository provides an interactive `install.sh` helper. Run it as root to
copy the scripts to `/usr/local/bin` and optionally set up the services for
`x708-pwr.sh`, `bat.py`, and `fan.py`. The installer can also install the required
`gpiod` and Python packages for you.

```bash
sudo ./install.sh
```

## Scripts

### x708-pwr.sh
Monitors the shutdown and reboot buttons. The boot line (GPIO 12) is held
high using `gpioset` for as long as the script runs. Run the script as root so
it can access the GPIO chip.

### x708-softsd.sh
Sends a pulse on GPIO 13 to tell the UPS to cut power after a delay. This
script also needs to run as root to access the GPIO line.

```bash
sudo ./x708-softsd.sh 6
```

Run the script before halting the Pi to let the UPS know it should cut
power:

```bash
sudo ./x708-softsd.sh 6
sudo shutdown -h now
```

### bat.py
Reads battery voltage and capacity over I2C once per minute. When the voltage
falls below 3&nbsp;V it toggles the shutdown line via `gpiod`. This script must
also be run as root so it can access I2C and GPIO.

### fan.py
Controls a cooling fan connected to a GPIO pin based on the CPU temperature.
It polls the temperature every few seconds using `vcgencmd` and turns the fan
on above the configured threshold. The fan is switched off again when the
temperature falls below a lower threshold. Run the script as root so it can
access the GPIO line. A `fan.service` unit is provided to run it
automatically.

### Running as a service

The repository includes systemd unit files. One runs `x708-pwr.sh` as root so
it can control the GPIO hardware. Copy the files and enable the unit with:

```bash
sudo cp x708-pwr.sh /usr/local/bin/
sudo cp x708-pwr.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-pwr.service
sudo systemctl start x708-pwr.service
```

Another unit file runs `bat.py` to monitor the battery level and trigger a
shutdown when it becomes too low:

```bash
sudo cp bat.py /usr/local/bin/
sudo cp x708-bat.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-bat.service
sudo systemctl start x708-bat.service
```

A third unit file runs `fan.py` to automatically control the cooling fan:

```bash
sudo cp fan.py /usr/local/bin/
sudo cp fan.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable fan.service
sudo systemctl start fan.service
```

## Monitoring the UPS battery

### Enabling the I²C interface

The UPS communicates over the Pi's I²C bus. Make sure the interface is enabled
before running `bat.py` or the `x708-bat.service` unit. Use
`raspi-config` to enable it under **Interface Options &rarr; I2C**:

```bash
sudo raspi-config
```

Alternatively edit `/boot/config.txt` and add
`dtparam=i2c_arm=on`, then reboot.

If the battery service fails to start with errors related to I²C, double-check
that the interface is enabled and that you have rebooted after making changes.

`bat.py` reads the battery voltage and capacity from the X708 over I2C using
`smbus2`. It polls once per minute and when the voltage drops below 3&nbsp;V the
script toggles the shutdown line via `gpiod`. Run it as root:

```bash
sudo python3 bat.py
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

