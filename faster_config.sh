#!/usr/bin/env bash
# Work in Progress, not tested! 
# Use this script to auto-configure OpenWRT to a set of predifined settings
# Use this script to quickly deploy and configure multiple modems on same of diferent networks.

DIR=$(temp=$( realpath "$0" ) && dirname "$temp")
echo $DIR

#__________ HOSTNAME ____________
#Update device name:
read -p 'Enter client name' CLIENTNAME
read -p 'Enter device name / SSID name: ' HOSTNAME
echo 'Setting up device name to: ' $HOSTNAME
if uci set system.system.hostname="$HOSTNAME" && echo $(uci get system.system.hostname) > /proc/sys/kernel/hostname; then
        uci commit system
        echo 'Device name updated to :' $(cat /proc/sys/kernel/hostname)
else
        echo 'Failed to update hostname, current hostname: ' $(cat /proc/sys/kernel/hostname)
#___________ PASSWORD ___________
#Update device passphrase
read -s 'Enter a new device passphrase: ' NEWPASS
passwd << EOF
$NEWPASS
$NEWPASS
EOF
echo 'Done...'

#__________ LAN ___________
#Update device LAN address
read -p 'Enter device LAN IP:' LANIPADDR
echo 'Updating device LAN IP Address'
uci set network.lan.ipaddr="$LANIPADDR" && echo  "LAN IP Updated: " $(uci get network.lan.ipaddr) || echo "Failed"
uci set network.lan.proto='static'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart

#__________ DHCP ___________
#Update dhcp settings
uci set dhcp.lan=dhcp
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.leasetime='12h'
uci set dhcp.lan.start='130'
uci set dhcp.lan.limit='120'
uci commit dhcp
/etc/init.d/odhcpd restart


#__________ TIMEZONE ZONENAME ___________
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

#____________ WIRELESS _____________
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


#_____________MQTT___________
#Install MQTT packages.
opkg install mosquitto-ssl
opkg install mqtt-modbus-gateway
opkg install mqtt_pub
opkg install mtd
#Create a new password file and add user riot.
mosquitto_passwd -c /etc/mosquitto/passwd riot <<EOF
riot
EOF

#Overwrite mosquitto.conf file.
echo "user root
port 1883
allow_anonymous false
password_file /etc/mosquitto/passwd" > /etc/mosquitto/mosquitto.conf
#Enable mosquitto service
service mosquitto start
# NOTE!!! Above script works if the device has not been epanded with an SD card,
# if so, update the mosquitto configuration with the following code
#uci set mosquitto.mqtt.password_file='/etc/mosquitto/passwd'
#uci commit
#/etc/init.d/mosquitto restart

#___________PYTHON____________
#Install python packages
opkg update
opkg install python3-light
opkg install python3-pip
okpg install python3-pyserial
okpg install python3-paho-mqtt
#Install wheel
pip3 install wheel

#__________ GIT __________
#Install git and clone riot exect repos
opkg install git git-http

#___________RIOT__________
#Clone riot repositories
mkdir -p ~/riot_src/root/src
cd ~/riot_src/root/src
echo "Extracting riot exect files from TRAC Git Server"
read -p "Enter your TRAC username: " TRAC_USER
read -s "Enter your TRAC userpass: " TRAC_USER_PASS
cat << EOF
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/exec
$TRAC_USER_PASS
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/channels/exec_channel_sockets
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/channels/exec_channel_tty
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/drivers/exec_driver_modbus
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/drivers/exec_driver_mercury
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/routines/exec_routine_icsgw
git clone ssh://$TRAC_USER@domain.com:/srv/git/exec/routines/exec_routine_hornermb
EOF

#Install exec
pip3 install ~/src/exec/exec
pip3 install ~/src/exec/channels/exec_channel_sockets
pip3 install ~/src/exec/channels/exec_channel_tty
pip3 install ~/src/exec/drivers/exec_driver_modbus
pip3 install ~/src/exec/drivers/exec_driver_mercury
pip3 install ~/src/exec/routines/exec_routine_icsgw
pip3 install ~/src/exec/routines/exec_routine_hornermb

#___________ OPENVPN ___________
#Instal and configure an openvpn-client
opkg install openvpn-easy-rsa openvpn-openssl

#Autostart on router startup
/etc/init.d/openvpn enable

#Configure instance as client