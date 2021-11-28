#!/bin/bash

######################################################################
# tested on RPi4B and 2021-10-30-raspios-bullseye-armhf.zip


##################################################################
BACKUP_FILE=backup.tar.xz
BACKUP_TRANSFORM=s/^/$(date +%Y-%m-%dT%H_%M_%S)-stratum1\\//

do_backup() {
    tar -ravf "$BACKUP_FILE" --transform="$BACKUP_TRANSFORM" -C / "$1" &>/dev/null
}


##################################################################
SCRIPT_DIR=`dirname "${BASH_SOURCE[0]}"`
if ! [ -d "$SCRIPT_DIR/etc/chrony/stratum1" ]; then
    echo -e "\e[1;31m'$SCRIPT_DIR'\e[0m";
    echo -e "\e[1;31mcan not find required files\e[0m";
    exit 1
fi


######################################################################
handle_update() {
    echo -e "\e[32mhandle_update()\e[0m";

    sudo sync \
    && echo -e "\e[32mupdate...\e[0m" && sudo apt update \
    && echo -e "\e[32mupgrade...\e[0m" && sudo apt full-upgrade -y \
    && echo -e "\e[32mautoremove...\e[0m" && sudo apt autoremove -y --purge \
    && echo -e "\e[32mautoclean...\e[0m" && sudo apt autoclean \
    && echo -e "\e[32mDone.\e[0m" \
    && sudo sync;
}


######################################################################
handle_gps() {
    echo -e "\e[32mhandle_gps()\e[0m";

    ##################################################################
    echo -e "\e[36m    prepare GPS\e[0m";
    ##################################################################
    echo -e "\e[36m    setup serial port: /dev/ttyAMA0\e[0m";
    sudo raspi-config nonint do_serial 2;
    sudo systemctl disable --now hciuart;

    ##################################################################
    echo -e "\e[36m    install gpsd\e[0m";
    sudo apt-get -y install gpsd gpsd-clients;
    sudo usermod -a -G dialout $USER

    ##################################################################
    echo -e "\e[36m    setup gpsd\e[0m";
    sudo systemctl stop --now gpsd.{service,socket};

    do_backup etc/default/gpsd
    cat << EOF | sudo tee /etc/default/gpsd &>/dev/null
# /etc/default/gpsd
## mod_install_stratum_one

# Default settings for the gpsd init script and the hotplug wrapper.

# Start the gpsd daemon automatically at boot time
START_DAEMON="true"

# Use USB hotplugging to add new USB devices automatically to the daemon
USBAUTO="true"

# Devices gpsd should collect to at boot time.
# They need to be read/writeable, either by user gpsd or the group dialout.
DEVICES="/dev/ttyAMA0 /dev/pps0"
# in case you have two pps devices connected
#DEVICES="/dev/ttyAMA0 /dev/pps0 /dev/pps1"

# Other options you want to pass to gpsd
GPSD_OPTIONS="-n -r -b"
#GPSD_OPTIONS="-n -r -b -s 115200"
EOF

    ##################################################################
    grep -q mod_install_stratum_one /lib/systemd/system/gpsd.socket &>/dev/null || {
        echo -e "\e[36m    fix gpsd to listen to all connection requests\e[0m";
        do_backup lib/systemd/system/gpsd.socket
        sudo sed /lib/systemd/system/gpsd.socket -i -e "s/^ListenStream=\[::1\]:2947/ListenStream=2947/";
        sudo sed /lib/systemd/system/gpsd.socket -i -e "s/^ListenStream=127.0.0.1:2947/#ListenStream=0.0.0.0:2947/";
        cat << EOF | sudo tee -a /lib/systemd/system/gpsd.socket &>/dev/null
;; mod_install_stratum_one
EOF
    }

    sudo systemctl daemon-reload;
    sudo systemctl enable gpsd;
    sudo systemctl restart gpsd;

    [ -f "/etc/dhcp/dhclient-exit-hooks.d/ntp" ] && {
        do_backup etc/dhcp/dhclient-exit-hooks.d/ntp
        sudo rm -f /etc/dhcp/dhclient-exit-hooks.d/ntp;
    }
}


######################################################################
handle_pps() {
    echo -e "\e[32mhandle_pps()\e[0m";

    ##################################################################
    echo -e "\e[36m    install PPS tools\e[0m";
    sudo apt-get -y install pps-tools;

    ##################################################################
    grep -q pps-gpio /boot/config.txt &>/dev/null || {
        echo -e "\e[36m    setup config.txt for PPS\e[0m";
        do_backup boot/config.txt
        cat << EOF | sudo tee -a /boot/config.txt &>/dev/null
[all]
#########################################
# https://www.raspberrypi.org/documentation/configuration/config-txt.md
# https://github.com/raspberrypi/firmware/tree/master/boot/overlays
## mod_install_stratum_one

# gps + pps + ntp settings

#Name:   disable-bt
#Info:   Disable onboard Bluetooth on Pi 3B, 3B+, 3A+, 4B and Zero W, restoring
#        UART0/ttyAMA0 over GPIOs 14 & 15.
#        N.B. To disable the systemd service that initialises the modem so it
#        doesn't use the UART, use 'sudo systemctl disable hciuart'.
#Load:   dtoverlay=disable-bt
#Params: <None>
dtoverlay=disable-bt


#Name:   pps-gpio
#Info:   Configures the pps-gpio (pulse-per-second time signal via GPIO).
#Load:   dtoverlay=pps-gpio,<param>=<val>
#Params: gpiopin                 Input GPIO (default "18")
#        assert_falling_edge     When present, assert is indicated by a falling
#                                edge, rather than by a rising edge (default
#                                off)
#        capture_clear           Generate clear events on the trailing edge
#                                (default off)
# note, the last listed entry will become /dev/pps0
#
#dtoverlay=pps-gpio,gpiopin=7  # /dev/pps1
dtoverlay=pps-gpio,gpiopin=4  # /dev/pps0
EOF
    }

    ##################################################################
    grep -q pps-gpio /etc/modules &>/dev/null || {
        echo -e "\e[36m    add pps-gpio to modules for PPS\e[0m";
        do_backup etc/modules
        echo 'pps-gpio' | sudo tee -a /etc/modules &>/dev/null
    }
}


######################################################################
disable_ntp() {
    echo -e "\e[32mdisable_ntp()\e[0m";
    sudo systemctl disable --now ntp &>/dev/null;
}



######################################################################
install_chrony() {
    echo -e "\e[32minstall_chrony()\e[0m";
    sudo apt-get -y install chrony;
    sudo apt install -y --no-install-recommends gnuplot;
}


######################################################################
setup_chrony() {
    echo -e "\e[32msetup_chrony()\e[0m";

    sudo systemctl stop chrony;

    do_backup etc/chrony/chrony.conf
    sudo mv /etc/chrony/chrony.conf{,.original}

    sudo cp -Rv $SCRIPT_DIR/etc/chrony/* /etc/chrony/;

    sudo systemctl enable chrony;
    sudo systemctl restart chrony;
}


######################################################################
install_ptp() {
    echo -e "\e[32minstall_ptp()\e[0m";
    sudo apt-get -y install linuxptp;
    sudo ethtool --set-eee eth0 eee off &>/dev/null;
    sudo systemctl enable --now ptp4l.service;
}


######################################################################
# kernel config
######################################################################
#nohz=off intel_idle.max_cstate=0
#
### PPS (default in Raspberry Pi OS)
#CONFIG_PPS=y
#CONFIG_PPS_CLIENT_LDISC=y
#CONFIG_PPS_CLIENT_GPIO=y
#CONFIG_GPIO_SYSFS=y
#
### PTP (optional addition)
#CONFIG_DP83640_PHY=y
#CONFIG_PTP_1588_CLOCK_PCH=y
#
### KPPS + tuning (optional addition)
#CONFIG_NTP_PPS=y
#CONFIG_PREEMPT_NONE=y
## CONFIG_PREEMPT_VOLUNTARY is not set
## CONFIG_NO_HZ is not set
## CONFIG_HZ_100 is not set
#CONFIG_HZ_1000=y
#CONFIG_HZ=1000
######################################################################

######################################################################
## test commands
######################################################################
#dmesg | grep pps
#sudo ppstest /dev/pps*
#sudo ppswatch -a /dev/pps0
#
#sudo gpsd -D 5 -N -n /dev/ttyAMA0 /dev/pps0 -F /var/run/gpsd.sock
#sudo systemctl stop gpsd.*
#sudo killall -9 gpsd
#sudo dpkg-reconfigure -plow gpsd
#minicom -b 9600 -o -D /dev/ttyAMA0
#cgps
#xgps
#gpsmon
#ipcs -m
#ntpshmmon
#
#sudo systemctl stop gpsd.* && sudo systemctl restart chrony && sudo systemctl start gpsd && echo Done.
#
#chronyc sources
#chronyc sourcestats
#chronyc tracking
#watch -n 10 -p sudo chronyc -m tracking sources sourcestats clients;
######################################################################


handle_update

handle_gps
handle_pps

disable_ntp;

install_chrony;
setup_chrony;

#install_ptp;


######################################################################
echo -e "\e[32mDone.\e[0m";
echo -e "\e[1;31mPlease reboot\e[0m";
