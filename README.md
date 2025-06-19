# pi-pwr-button

Script to handle power events on the X708 UPS for Raspberry Pi.

Run the `x708-pwr.sh` script as root to monitor the shutdown and reboot
buttons. The script automatically cleans up the GPIO pins on exit so it
can be safely integrated into a service.
