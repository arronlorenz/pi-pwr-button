#!/usr/bin/env python3
import os
import struct
import sys
import time

try:
    from smbus2 import SMBus
except ImportError:
    sys.exit(
        "The smbus2 module is required. Install it with 'sudo apt-get install "
        "python3-smbus2' or 'python3 -m pip install smbus2'."
    )

try:
    import gpiod
except ImportError:
    sys.exit(
        "The gpiod module is required. Install it with 'sudo apt-get install "
        "python3-libgpiod'."
    )

PIN = 13
CHIP = "gpiochip0"

# How often to check the battery state. The Pi can run on battery for hours
# so reading once per minute is sufficient.
CHECK_INTERVAL = 60

line = None


def readVoltage(bus):
    address = 0x36
    read = bus.read_word_data(address, 2)
    swapped = struct.unpack("<H", struct.pack(">H", read))[0]
    voltage = swapped * 1.25 / 1000 / 16
    return voltage


def readCapacity(bus):
    address = 0x36
    read = bus.read_word_data(address, 4)
    swapped = struct.unpack("<H", struct.pack(">H", read))[0]
    capacity = swapped / 256
    if capacity > 100:
        capacity = 100
    return capacity


def main():
    global line
    if os.geteuid() != 0:
        sys.exit("Please run as root.")
    try:
        chip = gpiod.Chip(CHIP)
    except OSError as e:
        sys.exit(f"Failed to open GPIO chip '{CHIP}': {e}")

    try:
        bus = SMBus(1)
    except (FileNotFoundError, OSError) as e:
        sys.exit(f"Failed to open I\u00b2C bus: {e}")

    try:
        with chip, bus:
            line = chip.get_line(PIN)
            line.request(consumer="x708_bat", type=gpiod.LINE_REQ_DIR_OUT, default_vals=[0])

            while True:
                print("******************")

                voltage = readVoltage(bus)
                capacity = readCapacity(bus)

                print("Voltage:%5.2fV" % voltage)
                print("Battery:%5i%%" % capacity)

                if capacity >= 100:
                    print("Battery FULL")

                if capacity < 20:
                    print("Battery Low")

                # Set battery low voltage to shut down. You can modify this threshold
                # (range must be 2.5~4.1vdc)
                if voltage < 3.00:
                    print("Battery LOW!!!")
                    print("Shutdown in 5 seconds")
                    time.sleep(5)
                    line.set_value(1)
                    time.sleep(3)
                    line.set_value(0)

                time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        print("Exiting...")
    finally:
        # Ensure the pin is released and set low
        if line is not None:
            try:
                line.set_value(0)
                line.release()
            except Exception:
                pass


if __name__ == "__main__":
    main()
