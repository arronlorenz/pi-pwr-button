#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys
import time

try:
    import gpiod
except ImportError:
    sys.exit(
        "The gpiod module is required. Install it with 'sudo apt-get install "
        "python3-libgpiod'."
    )

if shutil.which("vcgencmd") is None:
    sys.exit(
        "vcgencmd command not found; install the 'libraspberrypi-bin' package."
    )


ON_THRESHOLD = 55  # (degrees Celsius) Fan turns on above this temperature.
OFF_THRESHOLD = 50  # (degrees Celsius) Fan turns off below this temperature.
SLEEP_INTERVAL = 5  # (seconds) How often to check the core temperature.
GPIO_PIN = 16  # GPIO pin used to control the fan.
CHIP = "gpiochip0"


def get_temp():
    """Get the core temperature.
    Run a shell script to get the core temp and parse the output.
    Raises:
        RuntimeError: if response cannot be parsed.
    Returns:
        float: The core temperature in degrees Celsius.
    """
    output = subprocess.run(["vcgencmd", "measure_temp"], capture_output=True)
    temp_str = output.stdout.decode()
    try:
        return float(temp_str.split("=")[1].split("'")[0])
    except (IndexError, ValueError):
        raise RuntimeError('Could not parse temperature output.')


if __name__ == '__main__':
    if OFF_THRESHOLD >= ON_THRESHOLD:
        raise RuntimeError('OFF_THRESHOLD must be less than ON_THRESHOLD')
    if os.geteuid() != 0:
        sys.exit('Please run as root.')

    with gpiod.Chip(CHIP) as chip:
        line = chip.get_line(GPIO_PIN)
        line.request(consumer='fan_ctrl', type=gpiod.LINE_REQ_DIR_OUT, default_vals=[0])

        try:
            while True:
                temp = get_temp()

                if temp > ON_THRESHOLD and not line.get_value():
                    line.set_value(1)
                elif line.get_value() and temp < OFF_THRESHOLD:
                    line.set_value(0)

                time.sleep(SLEEP_INTERVAL)
        except KeyboardInterrupt:
            pass
        finally:
            try:
                line.set_value(0)
                line.release()
            except Exception:
                pass

