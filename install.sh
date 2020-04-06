#!/bin/bash -e

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root. Meaning: sudo ./install.sh" ; exit 1 ; fi

echo
echo -n "Do you want to install Volumio Bluetooth Audio (BlueALSA)? [y/N] "
read REPLY
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then exit 0; fi

#install dependencies
echo "Installing dependencies...\n"
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

# WoodenBeaver sounds
echo "Put connect/disconnect sound files in place\n"
mkdir -p /usr/local/share/sounds/WoodenBeaver/stereo
if [ ! -f /usr/local/share/sounds/WoodenBeaver/stereo/device-added.wav ]; then
    cp sound/device-added.wav /usr/local/share/sounds/WoodenBeaver/stereo/
fi
if [ ! -f /usr/local/share/sounds/WoodenBeaver/stereo/device-removed.wav ]; then
    cp sound/device-removed.wav /usr/local/share/sounds/WoodenBeaver/stereo/
fi

# Bluetooth settings - Class = 0x200414 / 0x200428
echo "Performing bluetooth settings in various files.\n"
echo "Updating audio.conf\n"
cat <<'EOF' > /etc/bluetooth/audio.conf
[General]
Class = 0x200428
Enable = Source,Sink,Media,Socket
EOF

echo "Updating main.conf\n"
cat <<'EOF' > /etc/bluetooth/main.conf
[General]
Class = 0x200428
DiscoverableTimeout = 0
[Policy]
AutoEnable=true
EOF

# Make Bluetooth discoverable after initialisation
echo "Make Bluetooth discoverable after initialisation\n"
mkdir -p /lib/systemd/system/bthelper@.service.d
cat <<'EOF' > /lib/systemd/system/bthelper@.service.d/override.conf
[Service]
ExecStartPost=/usr/bin/bluetoothctl discoverable on
ExecStartPost=/bin/hciconfig %I piscan
ExecStartPost=/bin/hciconfig %I sspmode 1
EOF

# Bluetooth agent
echo "Create the Bluetooth agent (its the thing that allows your devices to connect)\n"
cat <<'EOF' > /usr/local/bin/a2dp-agent.py
#!/usr/bin/python
from __future__ import absolute_import, print_function, unicode_literals
from gi.repository import GObject
import sys
import dbus
import dbus.service
import dbus.mainloop.glib
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = "/test/agent"
bus = None
device_obj = None
dev_path = None
def set_trusted(path):
    props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
    props.Set("org.bluez.Device1", "Trusted", True)
class Agent(dbus.service.Object):
    exit_on_release = True
    def set_exit_on_release(self, exit_on_release):
        self.exit_on_release = exit_on_release
    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        print("Release")
        if self.exit_on_release:
            mainloop.quit()
    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print("AuthorizeService (%s, %s)" % (device, uuid))
        set_trusted(device)
        return
    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print("RequestPinCode (%s)" % (device))
        set_trusted(device)
        return "0000"
    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print("RequestPasskey (%s)" % (device))
        set_trusted(device)
        return dbus.UInt32("0000")
    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print("DisplayPasskey (%s, %06u entered %u)" % (device, passkey, entered))
    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print("DisplayPinCode (%s, %s)" % (device, pincode))
    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print("RequestConfirmation (%s, %06d)" % (device, passkey))
        set_trusted(device)
        return
    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print("RequestAuthorization (%s)" % (device))
        set_trusted(device)
        return
    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")
if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)
    obj = bus.get_object("org.bluez", "/org/bluez");
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    print("A2DP Agent registered")
    manager.RequestDefaultAgent(AGENT_PATH)
    mainloop = GObject.MainLoop()
    mainloop.run()
EOF
chmod 755 /usr/local/bin/a2dp-agent.py

cat <<'EOF' > /lib/systemd/system/a2dp-agent.service
[Unit]
Description=Bluetooth A2DP Agent
Requires=bluetooth.service
After=bluetooth.service
[Service]
ExecStart=/usr/local/bin/a2dp-agent.py
RestartSec=5
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable a2dp-agent.service

# BlueALSA
mkdir -p /lib/systemd/system/bluealsa.service.d
cat <<'EOF' > /lib/systemd/system/bluealsa.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/bluealsa -i hci0 -p a2dp-sink
RestartSec=5
Restart=always
EOF

cat <<'EOF' > /lib/systemd/system/bluealsa-aplay.service
[Unit]
Description=BlueALSA aplay %I -dhw:1,0
Requires=bluealsa.service
After=bluealsa.service sound.target
[Service]
Type=simple
User=volumio
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/bluealsa-aplay %I -dhw:1,0 --pcm-buffer-time=250000 00:00:00:00:00:00
RestartSec=5
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable bluealsa-aplay

# Bluetooth udev script
echo "Bluetooth udev script\n"
cat <<'EOF' > /usr/local/bin/bluetooth-udev
#!/bin/bash
if [[ ! $NAME =~ ^\"([0-9A-F]{2}[:-]){5}([0-9A-F]{2})\"$ ]]; then exit 0; fi
action=$(expr "$ACTION" : "\([a-zA-Z]\+\).*")
if [ "$action" = "add" ]; then
    bluetoothctl discoverable off
    if [ -f /usr/local/share/sounds/WoodenBeaver/stereo/device-added.wav ]; then
        aplay -q /usr/local/share/sounds/WoodenBeaver/stereo/device-added.wav
    fi
    # disconnect wifi to prevent dropouts
    #ifconfig wlan0 down &
fi
if [ "$action" = "remove" ]; then
    if [ -f /usr/local/share/sounds/WoodenBeaver/stereo/device-removed.wav ]; then
        aplay -q /usr/local/share/sounds/WoodenBeaver/stereo/device-removed.wav
    fi
    # reenable wifi
    #ifconfig wlan0 up &
    bluetoothctl discoverable on
fi
EOF
chmod 755 /usr/local/bin/bluetooth-udev

cat <<'EOF' > /etc/udev/rules.d/99-bluetooth-udev.rules
SUBSYSTEM=="input", GROUP="input", MODE="0660"
KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluetooth-udev"
EOF
echo "Done! After rebooting you should be able to connect your devices. Now type: sudo reboot\n"

