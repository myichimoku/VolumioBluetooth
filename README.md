# VolumioBluetooth

A simple, light weight Bluetooth audio receiver for volumio 2 on Raspi.

## Features

Devices like phones, tablets and computers can play audio to the volumio Raspberry Pi.

## Requirements

- Raspberry Pi with Bluetooth support (tested wth Raspberry Pi 3)
- Volumio 2

## Installation

SSH into your Volumio Raspi and copy/paste each of these lines.

    wget -q https://github.com/myichimoku/VolumioBluetooth/archive/master.zip
    sudo apt-get update
    sudo apt-get install unzip
    unzip master.zip
    rm master.zip

    cd VolumioBluetooth-master
    sudo chmod 755 install.sh
    sudo ./install.sh

### Bluetooth

Sets up Bluetooth, adds a simple agent that accepts every connection, and enables audio playback through [BlueALSA](https://github.com/Arkq/bluez-alsa). A udev script is installed that disables discoverability while connected.

## Disclaimer

These scripts are tested and work on a current (as of April 2020) Volumio 2 setup on Raspberry Pi. Depending on your setup (board, configuration, sound module, Bluetooth adapter) and your preferences, you might need to adjust the scripts. They are held as simple as possible and can be used as a starting point for additional adjustments.

## References
https://learn.adafruit.com/install-bluez-on-the-raspberry-pi/installation
http://www.bluez.org/download/

https://github.com/nicokaiser/rpi-audio-receiver

https://forum.volumio.org/volumio-bluetooth-receiver-t8937.html

