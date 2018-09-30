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
# This script is part 2 of 2. 
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

#########  Test wlan0
echo PART 2 of 2 : SETUP WIFI ACCESS POINT AND MANAGAED CLIENT
echo
echo This script will reconfigure the wifi to an access point and managed client.
echo This script will make major changes to your network configuration.
read -p 'Click any key to continue.  Click q to quit.'  user_quit
if [ "$user_quit" = "q" ]
then
  exit
fi
echo Testing wlan0
echo starting the wlan0 service
sudo systemctl start wpa_supplicant@wlan0.service
echo
echo show the status
systemctl status wpa_supplicant@wlan0.service
echo
echo confirm there is an access point to connect to.
iwlist wlan0 scan | grep ESSID
read -p  'If the right access point is not found, press q to exit.'  user_quit
if [ "$user_quit" = "q" ]
then
  echo The access point you want to connect to may not be running or in range. Go back and troubleshoot.
  exit
fi
echo Confirm wlan0 is connected to an access point
iw wlan0 info
read -p  'If wlan0 is not connected to an access point, press q to exit.'  user_quit
if [ "$user_quit" = "q" ]
then
  echo Check that the SSID and pass phrase values are correct. Go back and troubleshoot.
  exit
fi
echo Confirm wlan0 has been assigned an IP address
ifconfig wlan0 | grep -w inet 
read -p  'If wlan0 does not have an IP address, press q to exit.'  user_quit
if [ "$user_quit" = "q" ]
then
  echo Something is not right.  Go back and troubleshoot.
  exit
fi
echo Confirm Internet access
ping -I wlan0 -c3 google.com
echo
echo Check that ap0 can be set and deleted
sudo iw dev wlan0 interface add ap0 type__ap
echo Get the ap0 status
sudo iw dev ap0 info
read -p  'If ap0 is not loaded and active, press q to exit.'  user_quit
if [ "$user_quit" = "q" ]
then
  echo Something is not right.  Go back and troubleshoot.
  exit
fi
sudo iw dev ap0 del
echo Completed test of ap0. 
read -p 'Press any key to continue with installation of hostapd'  user_go


#########  Setup
echo SETTING UP WLAN0 AND AP0
echo PART 2 : Install hostapd

sudo apt update
sudo apt install rng-tools hostapd
sudo systemctl stop hostapd

echo Creating the file with your settings for ssid= and wpa_passphrase=:
echo
cat > ~/hostapd.conf <<EOF
interface=ap0
driver=nl80211
ssid="$ap0_SSID"
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase="$ap0_PP"
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

sudo mv ~/hostapd.conf /etc/hostapd/hostapd.conf
sudo chmod 600 /etc/hostapd/hostapd.conf
sudo chown root:root /etc/hostapd/hostapd.conf

echo
echo 'Setting DAEMON_CONF="/etc/hostapd/hostapd.conf" in /etc/default/hostapd'
sudo sed -i 's/^#DAEMON_CONF=.*$/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd
echo 'adding a # to the line # Should-Start: to disable old SysV init system'
echo 'Changing the line # Should-Start: ... by adding ## at the beginning'
sudo sed -i -e 's/# Should-Start:/## Should-Start:/' /etc/init.d/hostapd
echo Reading the line from the /etc/default/hostapd file:

echo
echo
echo Creating ap0 service
sudo mkdir -p /etc/systemd/system/hostapd.service.d
sudo chmod 755 /etc/systemd/system/hostapd.service.d

cat > ~/override.conf <<EOF
[Service]
ExecStartPre=/sbin/iw dev wlan0 interface add ap0 type __ap
EOF

sudo mv ~/override.conf /etc/systemd/system/hostapd.service.d/override.conf
sudo chmod 644 /etc/systemd/system/hostapd.service.d/override.conf
sudo chown root:root /etc/systemd/system/hostapd.service.d/override.conf

sudo systemctl daemon-reload
echo Start wpa_supplicant after hostapd
sudo mkdir -p /etc/systemd/system/wpa_supplicant@wlan0.service.d
sudo chmod 755 /etc/systemd/system/wpa_supplicant@wlan0.service.d
cat > ~/override.conf <<EOF
[Unit]
After=hostapd.service
EOF
sudo mv ~/override.conf  /etc/systemd/system/wpa_supplicant@wlan0.service.d/override.conf
sudo chmod 644 /etc/systemd/system/wpa_supplicant@wlan0.service.d/override.conf
sudo chown root:root /etc/systemd/system/wpa_supplicant@wlan0.service.d/override.conf

sudo systemctl daemon-reload
echo Checking ap0 that ap0 has an ip address:
ifconfig ap0 | grep inet
echo Checking the status of wlan0 and ap0:
sudo systemctl status wpa_supplicant@wlan0.service
echo
echo
echo  Setup of wlan0 and ap0 now complete.
echo
echo
