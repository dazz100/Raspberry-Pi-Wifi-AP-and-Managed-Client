#!/bin/bash
# Sets up a wifi access point and managed client running together on a Raspberry Pi
# This script is wholly based on instructions by Ingo found at the link:
# https://raspberrypi.stackexchange.com/questions/87504/raspberry-pi-zero-w-as-a-wifi-repeater/87506#87506
# This setup creates an ap and managed client that are stand-alone. 
#
# IP forwarding is not enabled in this script.  If required, that needs to be done with IPForward in
# /etc/systemd/network/12-ap0.network so it sends all packages with unknown destination addresses, e.g.
# internet addresses to the next hop to the internet router.  Also a static route would be required so packets
# can find the route for returning packages from the internet over the RasPi to the network from the access
# point.
# 
# This script is part 1 of 2. 
# Part 1 is run before the Pi is rebooted.
# Part 2 is run after the reboot.
# This script was tested with the 2018-06-27 release of Raspbian Stretch
# running on a Raspberry Pi 3B.
# version 1.0  30 Sept 2018
#
######### Variables

## wlan0
# enter the values of the access point you want the wlan0 managed client to connect with
# This setup assumes that wlan0 will be assigned a IP by the AP dhcp server
#  SSID
wlan0_SSID=MyNetwork
#  Pass Phrase.  Must be more than 8 characters long
wlan0_PP=SuperSecret


## ap0
# enter the values that other wifi clients will use to connect to ap0
#  SSID
ap0_SSID=MyID
#  Pass Phrase other wifi clients will use
ap0_PP=MostSecret
#  The static IP address assigned to ap0
ap0_IP="1.2.3.4/24"

#########  Setup systemd-networkd
echo PART 1 of 2 : SETUP WIFI ACCESS POINT AND MANAGAED CLIENT
echo
echo This script will reconfigure the wifi to an access point and managed client.
echo This script will make major changes to your network configuration.
read -p 'Click any key to continue.  Click q to quit.'  user_quit
if [ "$user_quit" = "q" ]
then
  exit
fi

echo
echo Creating Journal
sudo ~# mkdir -p /var/log/journal
echo Ignore the warnings below.  They are normal and harmless.
sudo systemd-tmpfiles --create --prefix /var/log/journal 
echo Disabling networking and dhcpcd services.
sudo systemctl mask networking.service
sudo systemctl mask dhcpcd.service
echo renaming the network interfaces file to make it inactive
sudo mv /etc/network/interfaces /etc/network/interfaces~
sudo sed -i '1i resolvconf=NO' /etc/resolvconf.conf
echo Enabling the new systemd-networkd services
sudo systemctl enable systemd-networkd.service
sudo systemctl enable systemd-resolved.service
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
echo
echo
echo Setting up wlan0 and ap0 interface files 
cat > ~/08-wlan0.network <<EOF
[Match]
Name=wlan0
[Network]
DHCP=yes
EOF

sudo mv ~/08-wlan0.network /etc/systemd/network/08-wlan0.network
sudo chown root:root /etc/systemd/network/08-wlan0.network

cat > ~/12-ap0.network <<EOF
[Match]
Name=ap0
[Network]
Address="$ap0_IP"
DHCPServer=yes
IPForward=no
EOF

sudo mv ~/12-ap0.network /etc/systemd/network/12-ap0.network
sudo chown root:root /etc/systemd/network/12-ap0.network

echo Setting up wpa_supplicant files
cat > ~/wpa_supplicant-wlan0.conf <<EOF
country=NZ
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$wlan0_SSID"
    psk="$wlan0_PP"
}
EOF

sudo mv ~/wpa_supplicant-wlan0.conf /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
sudo chown root:root /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

sudo systemctl disable wpa_supplicant.service
sudo rm /etc/wpa_supplicant/wpa_supplicant.conf

sudo systemctl enable wpa_supplicant@wlan0.service

echo  Part 1 complete.  
echo wlan0 should be fully operational after a reboot.
echo ap0 does not work yet because it has not been created yet.
echo 
echo
echo  REBOOT NOW