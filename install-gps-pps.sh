#!/bin/bash

######################################################################
# tested on RPi4B and 2020-05-27-raspios-buster-armhf.zip

BACKUP_FILE=backup.tar.xz

##################################################################
SCRIPT_DIR=`dirname "${BASH_SOURCE[0]}"`
if ! [ -d "$SCRIPT_DIR/etc/chrony/stratum1" ]; then
    echo -e "\e[1;31m'$SCRIPT_DIR'\e[0m";
    echo -e "\e[1;31mcan not find required files\e[0m";
    exit 1
fi

##################################################################
# if a GPS module is already installed and is giving GPS feed on the GPIO-serial port,
# it can generate error messages to the console, because the kernel try to interprete this as commands from the boot console
sudo systemctl --now disable serial-getty@serial0.service;
sudo systemctl --now disable serial-getty@ttyAMA0.service;
sudo systemctl --now disable hciuart.service;


######################################################################
handle_timezone() {
    echo -e "\e[32mhandle_timezone()\e[0m";

    echo -e "\e[36m    prepare timezone to Etc/UTC\e[0m";
    tar -ravf $BACKUP_FILE -C / etc/timezone
    echo 'Etc/UTC' | sudo tee /etc/timezone &>/dev/null
    sudo dpkg-reconfigure -f noninteractive tzdata;
}


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
    echo -e "\e[36m    make boot quiet to serial port: serial0\e[0m";
    sudo systemctl --now disable serial-getty@serial0.service;
    sudo systemctl --now disable serial-getty@ttyAMA0.service;
    sudo systemctl --now disable hciuart.service;
    tar -ravf $BACKUP_FILE -C / boot/cmdline.txt
    sudo sed -i -e "s/console=serial0,115200//" /boot/cmdline.txt;
    sudo sed -i -e "s/console=ttyAMA0,115200//" /boot/cmdline.txt;

    ##################################################################
    echo -e "\e[36m    install gpsd\e[0m";
    sudo apt-get -y install gpsd gpsd-clients;
    sudo apt-get -y install --no-install-recommends python-gi-cairo;

    sudo usermod -a -G dialout $USER

    ##################################################################
    echo -e "\e[36m    setup gpsd\e[0m";
    sudo systemctl stop gpsd.*;

    tar -ravf $BACKUP_FILE -C / etc/default/gpsd
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
DEVICES="/dev/serial0 /dev/pps0"
# in case you have two pps devices connected
#DEVICES="/dev/serial0 /dev/pps0 /dev/pps1"

# Other options you want to pass to gpsd
GPSD_OPTIONS="-n -r -b"
EOF
    sudo systemctl enable gpsd;
    sudo systemctl restart gpsd;

    ##################################################################
    grep -q mod_install_stratum_one /lib/systemd/system/gpsd.socket &>/dev/null || {
        echo -e "\e[36m    fix gpsd to listen to all connection requests\e[0m";
        tar -ravf $BACKUP_FILE -C / lib/systemd/system/gpsd.socket
        sudo sed /lib/systemd/system/gpsd.socket -i -e "s/ListenStream=127.0.0.1:2947/ListenStream=0.0.0.0:2947/";
        cat << EOF | sudo tee -a /lib/systemd/system/gpsd.socket &>/dev/null
;; mod_install_stratum_one
EOF
    }

    [ -f "/etc/dhcp/dhclient-exit-hooks.d/ntp" ] && {
        tar -ravf $BACKUP_FILE -C / etc/dhcp/dhclient-exit-hooks.d/ntp
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
        tar -ravf $BACKUP_FILE -C / boot/config.txt
        cat << EOF | sudo tee -a /boot/config.txt &>/dev/null
[all]
#########################################
# https://www.raspberrypi.org/documentation/configuration/config-txt.md
# https://github.com/raspberrypi/firmware/tree/master/boot/overlays
## mod_install_stratum_one

# gps + pps + ntp settings

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
# dtoverlay=pps-gpio,gpiopin=4,assert_falling_edge,capture_clear
#dtoverlay=pps-gpio,gpiopin=7,capture_clear  # /dev/pps1
dtoverlay=pps-gpio,gpiopin=4,capture_clear  # /dev/pps0


#Name:   disable-bt
#Info:   Disable onboard Bluetooth on Pi 3B, 3B+, 3A+, 4B and Zero W, restoring
#        UART0/ttyAMA0 over GPIOs 14 & 15.
#        N.B. To disable the systemd service that initialises the modem so it
#        doesn't use the UART, use 'sudo systemctl disable hciuart'.
#Load:   dtoverlay=disable-bt
#Params: <None>
dtoverlay=disable-bt
#alias for backwards compatibility.
dtoverlay=pi3-disable-bt


# Enable UART
enable_uart=1
EOF
    }

    ##################################################################
    grep -q pps-gpio /etc/modules &>/dev/null || {
        echo -e "\e[36m    add pps-gpio to modules for PPS\e[0m";
        tar -ravf $BACKUP_FILE -C / etc/modules
        echo 'pps-gpio' | sudo tee -a /etc/modules &>/dev/null
    }
}


######################################################################
######################################################################
disable_ntp() {
    echo -e "\e[32mdisable_ntp()\e[0m";
    sudo systemctl --now disable ntp &>/dev/null;
}



######################################################################
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

    tar -ravf $BACKUP_FILE -C / etc/chrony/chrony.conf
    sudo mv /etc/chrony/chrony.conf{,.original}

    sudo cp -Rv $SCRIPT_DIR/etc/chrony/* /etc/chrony/;

    sudo systemctl enable chrony;
    sudo systemctl restart chrony;
}


######################################################################
disable_chrony() {
    echo -e "\e[32mdisable_chrony()\e[0m";
    sudo systemctl --now disable chrony &>/dev/null;
}



######################################################################
handle_samba() {
    echo -e "\e[32mhandle_samba()\e[0m";

    ##################################################################
    echo -e "\e[36m  install samba\e[0m";
    sudo apt-get -y install samba;

    ##################################################################
    [ -d "/media/share" ] || {
        echo -e "\e[36m  create share folder\e[0m";
        sudo mkdir -p /media/share;
    }

    ##################################################################
    grep -q mod_install_stratum_one /etc/samba/smb.conf &>/dev/null || \
    grep -q mod_install_server      /etc/samba/smb.conf &>/dev/null || \
    {
        echo -e "\e[36m  setup samba\e[0m";
        sudo systemctl stop smb.service;

        tar -ravf $BACKUP_FILE -C / etc/samba/smb.conf
        #sudo sed -i /etc/samba/smb.conf -n -e "1,/#======================= Share Definitions =======================/p";
        cat << EOF | sudo tee -a /etc/samba/smb.conf &>/dev/null
## mod_install_stratum_one
## mod_install_server

[share]
  comment = Share
  path = /media/share/
  public = yes
  only guest = yes
  browseable = yes
  read only = no
  writeable = yes
  create mask = 0644
  directory mask = 0755
  force create mode = 0644
  force directory mode = 0755
  force user = root
  force group = root

[ntpstats]
  comment = NTP Statistics
  path = /var/log/chrony/
  public = yes
  only guest = yes
  browseable = yes
  read only = yes
  writeable = no
  create mask = 0644
  directory mask = 0755
  force create mode = 0644
  force directory mode = 0755
  force user = root
  force group = root
EOF
        sudo systemctl restart smbd.service;
    }
}


######################################################################
handle_dhcpcd() {
    echo -e "\e[32mhandle_dhcpcd()\e[0m";

    grep -q mod_install_stratum_one /etc/dhcpcd.conf || \
    grep -q mod_install_server      /etc/dhcpcd.conf || \
    {
        echo -e "\e[36m    setup dhcpcd.conf\e[0m";
        tar -ravf $BACKUP_FILE -C / etc/dhcpcd.conf
        cat << EOF | sudo tee -a /etc/dhcpcd.conf &>/dev/null
## mod_install_stratum_one
#interface eth0
#static ip_address=192.168.1.101/24
#static routers=192.168.1.1
#static domain_name_servers=192.168.1.1
EOF
    }
}


######################################################################
disable_timesyncd() {
    echo -e "\e[32mdisable_timesyncd()\e[0m";
    sudo systemctl stop systemd-timesyncd
    sudo systemctl daemon-reload
    sudo systemctl disable systemd-timesyncd
}


######################################################################
install_ptp() {
    echo -e "\e[32minstall_ptp()\e[0m";
    sudo apt-get -y install linuxptp;
    sudo ethtool --set-eee eth0 eee off &>/dev/null;
    sudo systemctl --now enable ptp4l.service;
}


######################################################################
## test commands
######################################################################
#dmesg | grep pps
#sudo ppstest /dev/pps0
#sudo ppswatch -a /dev/pps0
#
#sudo gpsd -D 5 -N -n /dev/serial0 /dev/pps0 -F /var/run/gpsd.sock
#sudo systemctl stop gpsd.*
#sudo killall -9 gpsd
#sudo dpkg-reconfigure -plow gpsd
#minicom -b 9600 -o -D /dev/serial0
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


handle_timezone

handle_update

handle_gps
handle_pps

disable_timesyncd;
disable_ntp;

install_chrony;
setup_chrony;

install_ptp;
handle_samba;
handle_dhcpcd;


######################################################################
echo -e "\e[32mDone.\e[0m";
echo -e "\e[1;31mPlease reboot\e[0m";
