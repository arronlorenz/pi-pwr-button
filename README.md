# pi-pwr-button

Script to handle power events on the X708 UPS for Raspberry Pi.

Run the `x708-pwr.sh` script as root to monitor the shutdown and reboot
buttons. The script automatically cleans up the GPIO pins on exit so it
can be safely integrated into a service.

Use `x708-softsd.sh` to signal the UPS to cut power after a short delay.
Pass the delay in seconds as an optional argument (defaults to 4). The
script must also be run as root.

## Triggering a soft shutdown

Run the soft shutdown script before halting the Pi to let the UPS know it
should cut power:

```bash
sudo ./x708-softsd.sh 6
sudo shutdown -h now
```

## Running as a service

The repository includes a systemd unit file for running the power button
monitor as a service. Copy the script and service file and enable the
unit with the following commands:

```bash
sudo cp x708-pwr.sh /usr/local/bin/
sudo cp x708-pwr.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x708-pwr.service
sudo systemctl start x708-pwr.service
```

## Monitoring the UPS battery

The repository also includes `bat.py`, a small Python script that reads the
battery voltage and capacity from the X708 over I2C. When the voltage drops
below 3V the script sends a shutdown pulse on GPIO 13. Run it as root:

```bash
sudo python3 bat.py
```
