# pi-pwr-button

Utilities for handling power events on the X708 UPS for the Raspberry Pi 4.

## Dependencies

- `gpiod` for the `gpioset`/`gpioget` tools
- Python 3 with the `smbus2` and `gpiod` packages

Install them on a Debian based system with:

```bash
sudo apt-get install gpiod python3-libgpiod python3-smbus2
```

If `python3-smbus2` is not available on your system,
install the package with pip instead:

```bash
sudo pip3 install smbus2
```

## Scripts

### x708-pwr.sh
Monitors the shutdown and reboot buttons. The boot line (GPIO 12) is held
high using `gpioset` for as long as the script runs. The script requires
root privileges because it accesses the GPIO chip.

### x708-softsd.sh
Sends a pulse on GPIO 13 to tell the UPS to cut power after a delay. Run as
root so the script can access the GPIO line.

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
Reads battery voltage and capacity over I2C. When the voltage falls below
3&nbsp;V it toggles the shutdown line via `gpiod`. This script must also be
run as root so it can access I2C and GPIO.

### Running as a service

The repository includes a systemd unit file. Copy the files and enable the
unit with:

```bash
sudo cp x708-pwr.sh /usr/local/bin/
sudo cp x708-pwr.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-pwr.service
sudo systemctl start x708-pwr.service
```

## Monitoring the UPS battery

`bat.py` reads the battery voltage and capacity from the X708 over I2C using
`smbus2`. When the voltage drops below 3&nbsp;V the script toggles the shutdown
line via `gpiod`. Run it as root:

```bash
sudo python3 bat.py
```
