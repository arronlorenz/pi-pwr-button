#!/usr/bin/env python3
import os
import struct
import sys
import time
try:
    from smbus2 import SMBus
except ImportError as e:
    sys.exit("The smbus2 module is required. Install it with 'sudo apt-get install python3-smbus2' or 'sudo pip3 install smbus2'.")
import gpiod

PIN = 13
CHIP = "gpiochip0"

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
        with gpiod.Chip(CHIP) as chip, SMBus(1) as bus:
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

                time.sleep(2)
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
