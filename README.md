# pi-pwr-button

Utilities for handling power events on the X708 UPS for the Raspberry Pi 4.

## Dependencies

- `gpiod` for the `gpioset`/`gpioget` tools
- `i2c-tools` for `i2cget`
- `libraspberrypi-bin` for `vcgencmd`

The scripts check that these tools are installed and will exit with an error if
they are missing.

Install them on a Debian-based system with:

```bash
sudo apt-get install gpiod i2c-tools libraspberrypi-bin
```

## Installation script

The repository provides an interactive `install.sh` helper. Run it as root to
copy the scripts to `/usr/local/bin` and optionally set up the services for
`x708-pwr.sh`, `x708-bat.sh`, and `x708-fan.sh`. The installer can also install the required
packages for you.

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

### x708-bat.sh
Reads battery voltage and capacity over I2C once per minute using `i2cget`.
When the voltage falls below 3&nbsp;V it pulses the shutdown line with
`gpioset`. This script must run as root so it can access I2C and GPIO.

### x708-fan.sh
Controls a cooling fan connected to a GPIO pin based on the CPU temperature.
It polls the temperature every few seconds using `vcgencmd` and turns the fan
on above the configured threshold. The fan is switched off again when the
temperature falls below a lower threshold. Run the script as root so it can
access the GPIO line. An `x708-fan.service` unit is provided to run it automatically.

All scripts use `/dev/gpiochip0` by default. Set the `GPIO_CHIP` environment
variable (or override it in the service unit) to point at a different chip
path if needed.

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

Another unit file runs `x708-bat.sh` to monitor the battery level and trigger a
shutdown when it becomes too low:

```bash
sudo cp x708-bat.sh /usr/local/bin/
sudo cp x708-bat.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-bat.service
sudo systemctl start x708-bat.service
```

A third unit file runs `x708-fan.sh` to automatically control the cooling fan:

```bash
sudo cp x708-fan.sh /usr/local/bin/
sudo cp x708-fan.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-fan.service
sudo systemctl start x708-fan.service
```

## Monitoring the UPS battery

### Enabling the I²C interface

The UPS communicates over the Pi's I²C bus. Make sure the interface is enabled
before running `x708-bat.sh` or the `x708-bat.service` unit. Use
`raspi-config` to enable it under **Interface Options &rarr; I2C**:

```bash
sudo raspi-config
```

Alternatively edit `/boot/config.txt` and add
`dtparam=i2c_arm=on`, then reboot.

If the battery service fails to start with errors related to I²C, double-check
that the interface is enabled and that you have rebooted after making changes.

`x708-bat.sh` reads the battery voltage and capacity from the X708 over I2C using
`i2cget`. It polls once per minute and when the voltage drops below 3&nbsp;V the
script pulses the shutdown line with `gpioset`. Run it as root:

```bash
sudo ./x708-bat.sh
```

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

