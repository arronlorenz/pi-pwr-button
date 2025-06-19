# pi-pwr-button

Script to handle power events on the X708 UPS for Raspberry Pi.

Run the `x708-pwr.sh` script as root to monitor the shutdown and reboot
buttons. The script automatically cleans up the GPIO pins on exit so it
can be safely integrated into a service.

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
