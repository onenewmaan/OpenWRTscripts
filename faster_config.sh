#!/usr/bin/env bash
#
# Work in Progress, not tested! 
# Use this script to auto-configure OpenWRT to a set of predifined settings
# Use this script to quickly deploy and configure multiple modems on same of diferent networks.

DIR=$(temp=$( realpath "$0" ) && dirname "$temp")
echo $DIR

#Update device name
read -p 'Enter device name / SSID name: ' HOSTNAME
echo 'Setting up device name to: ' $HOSTNAME
uci set system.system.hostname="$HOSTNAME"
echo $(uci get system.system.hostname) > /proc/sys/kernel/hostname
echo 'Device name updated to :' $(cat /proc/sys/kernel/hostname)

#Update device passphrase
read -p 'Enter device passphrase: ' NEWPASS
echo 'Setting up the device passphrase'
passwd << EOF
$NEWPASS
$NEWPASS
EOF
echo 'Done...'

#Update device LAN address
read -p 'Enter device LAN IP:' LANIPADDR
echo 'Updating device LAN IP Address'
uci set network.lan.ipaddr="$LANIPADDR"


#Check and update timezone
echo 'Device timezone is set to : ' $(uci get system.system.timezone)
if [ $TIMEZONE != 'MDT']; then
        read -p 'Update timezone? (y/n): ' ANS_TIMEZONE
        if [ $ANS_TIMEZONE == 'y']; then
                read -p "Enter device timezone: " TIMEZONE
                uci set system.system.timezone="$TIMEZONE"
                echo 'Device timezone updated'
        else
                echo 'Timezone update skipped'
else
        echo 'Timezone unchanged'

#Check and update zonename
echo 'Device zonename is set to : ' $(uci get system.system.zoneName)
if [ $TIMEZONE != 'MDT']; then
        read -p 'Update zonename? (y/n): ' ANS_ZONENAME
        if [ $ANS_ZONENAME == 'y']; then
                read -p "Enter device zonename: " ZONENAME
                uci set system.system.zoneName="$ZONENAME"
                echo 'Device zonename updated'
        else
                echo 'Zonename update skipped'
else
        echo 'Zonename unchanged'

#Setup wireless access point
uci set wireless.radio0=wifi-device
uci set wireless.radio0.type='mac80211'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.hwmode='11ng'
uci set wireless.radio0.ht_capab='LDPC' 'SHORT-GI-20' 'SHORT-GI-40' 'TX-STBC' 'RX-STBC1' 'DSSS_CCK-40'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.path='platform/ahb/18100000.wmac'
uci set wireless.radio0.country='US'
uci set wireless.@wifi-iface[0]=wifi-iface
uci set wireless.@wifi-iface[0].device='radio0'
uci set wireless.@wifi-iface[0].network='lan'
uci set wireless.@wifi-iface[0].mode='ap'
uci set wireless.@wifi-iface[0].isolate='0'
uci set wireless.@wifi-iface[0].encryption='psk2+tkip+ccmp'
uci set wireless.@wifi-iface[0].wifi_id='wifi1'
uci set wireless.@wifi-iface[0].key='$NEWPASS'
uci set wireless.@wifi-iface[0].ssid='$HOSTNAME'

#Install packages
opkg update
opkg install python3-light
opkg install python3-pip
okpg install python3-pyserial
okpg install python3-paho-mqtt
okpg install mosquitto-ssl
opkg install openvpn-openssl

#Install wheel
pip3 install wheel

#Clone auto exect files
mkdir -p ~/auto_src/root/src
cd ~/auto_src/root/src

echo "Extracting auto exect files from TRAC Git Server"
read -p "Enter your TRAC username: " TRAC_USER
read -s "Enter your TRAC userpass: " TRAC_USER_PASS
cat << EOF 
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/auto_exec
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/channels/auto_exec_channel_sockets
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/channels/auto_exec_channel_tty
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/drivers/auto_exec_driver_modbus
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/drivers/auto_exec_driver_mercury
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/routines/auto_exec_routine_icsgw
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/auto/autoexec/routines/auto_exec_routine_hornermb
$TRAC_USER_PASS
EOF

#Configure MQTT broker
echo "allow_anonymous false
password_file /etc/mosquitto/passwd" > /etc/mosquitto/mosquitto.conf

#Install autoexec
pip3 install ~/src/autoexec/auto_exec
pip3 install ~/src/autoexec/channels/auto_exec_channel_sockets
pip3 install ~/src/autoexec/channels/auto_exec_channel_tty
pip3 install ~/src/autoexec/drivers/auto_exec_driver_modbus
pip3 install ~/src/autoexec/drivers/auto_exec_driver_mercury
pip3 install ~/src/autoexec/routines/auto_exec_routine_icsgw
pip3 install ~/src/autoexec/routines/auto_exec_routine_hornermb

#commit changes and restart netwrok
uci commit system
uci commit netwrok
/etc/init.d/network restart