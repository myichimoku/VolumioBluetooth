#!/bin/bash -e

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root. Meaning: sudo ./install.sh" ; exit 1 ; fi

echo
echo -n "Do you want to install Volumio Bluetooth Audio (BlueALSA)? [y/N] "
read REPLY
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then exit 0; fi

#install dependencies
echo "installing dependencies...\n"
sudo apt-get update
sudo apt-get install dh-autoreconf libasound2-dev libortp-dev pi-bluetooth
sudo apt-get install libusb-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev libsbc1 libsbc-dev

#Compile Bluez & Alsa

echo "Compiling Bluez. This can take up ~20 minutes...\n"
git clone git://git.kernel.org/pub/scm/bluetooth/bluez.git
cd bluez
git checkout 5.48
./bootstrap
./configure --enable-library --enable-experimental --enable-tools
make
sudo make install

sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so
sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so.3
sudo ln -s /usr/local/lib/libbluetooth.so.3.18.16 /usr/lib/arm-linux-gnueabihf/libbluetooth.so.3.18.16

echo "Compiling Bluez-Alsa.\n"
cd
git clone https://github.com/Arkq/bluez-alsa.git
cd bluez-alsa
autoreconf --install
mkdir build && cd build
../configure --disable-hcitop --with-alsaplugindir=/usr/lib/arm-linux-gnueabihf/alsa-lib
make
sudo make install
