#!/bin/bash

######################################################################
# 2020-02-13-raspbian-buster-lite

BACKUP_FILE=backup.tar.xz

##################################################################
# if a GPS module is already installed and is giving GPS feed on the GPIO-serial port,
# it can generate error messages to the console, because the kernel try to interprete this as commands from the boot console
sudo systemctl stop serial-getty@ttyAMA0.service;
sudo systemctl disable serial-getty@ttyAMA0.service;


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
    sudo systemctl stop serial-getty@ttyAMA0.service;
    sudo systemctl disable serial-getty@ttyAMA0.service;
    tar -ravf $BACKUP_FILE -C / boot/cmdline.txt
    sudo sed -i -e "s/console=serial0,115200//" /boot/cmdline.txt;
    sudo sed -i -e "s/console=ttyAMA0,115200//" /boot/cmdline.txt;

    ##################################################################
    echo -e "\e[36m    install gpsd\e[0m";
    sudo apt-get -y install gpsd gpsd-clients;

    ##################################################################
    echo -e "\e[36m    setup gpsd\e[0m";
    sudo systemctl stop gpsd.socket;
    sudo systemctl stop gpsd.service;

    tar -ravf $BACKUP_FILE -C / etc/default/gpsd
    cat << EOF | sudo tee /etc/default/gpsd &>/dev/null
# /etc/default/gpsd
## Stratum1
START_DAEMON=\"true\"
GPSD_OPTIONS=\"-n\"
DEVICES=\"/dev/ttyAMA0 /dev/pps0\"
USBAUTO=\"false\"
GPSD_SOCKET=\"/var/run/gpsd.sock\"
EOF
    sudo systemctl restart gpsd.service;
    sudo systemctl restart gpsd.socket;

    ##################################################################
    grep -q Stratum1 /lib/systemd/system/gpsd.socket &>/dev/null || {
        echo -e "\e[36m    fix gpsd to listen to all connection requests\e[0m";
        tar -ravf $BACKUP_FILE -C / lib/systemd/system/gpsd.socket
        sudo sed /lib/systemd/system/gpsd.socket -i -e "s/ListenStream=127.0.0.1:2947/ListenStream=0.0.0.0:2947/";
        cat << EOF | sudo tee -a /lib/systemd/system/gpsd.socket &>/dev/null
;; Stratum1
EOF
    }

    grep -q Stratum1 /etc/rc.local &>/dev/null || {
        echo -e "\e[36m    tweak GPS device at start up\e[0m";
        tar -ravf $BACKUP_FILE -C / etc/rc.local
        sudo sed /etc/rc.local -i -e "s/^exit 0$//";
        printf "## Stratum1
sudo systemctl stop gpsd.socket;
sudo systemctl stop gpsd.service;

# default GPS device settings at power on
stty -F /dev/ttyAMA0 9600

## custom GPS device settings
## 115200baud io rate,
#printf \x27\x24PMTK251,115200*1F\x5Cr\x5Cn\x27 \x3E /dev/ttyAMA0
#stty -F /dev/ttyAMA0 115200
## 10 Hz update interval
#printf \x27\x24PMTK220,100*2F\x5Cr\x5Cn\x27 \x3E /dev/ttyAMA0

sudo systemctl restart gpsd.service;
sudo systemctl restart gpsd.socket;

# workaround: lets start any gps client to forct gps service to wakeup and work
gpspipe -r -n 1 &

exit 0
" | sudo tee -a /etc/rc.local > /dev/null;
    }

    [ -f "/etc/dhcp/dhclient-exit-hooks.d/ntp" ] && {
        tar -ravf $BACKUP_FILE -C / etc/dhcp/dhclient-exit-hooks.d/ntp
        sudo rm -f /etc/dhcp/dhclient-exit-hooks.d/ntp;
    }

    [ -f "/etc/udev/rules.d/99-gps.rules" ] || {
        echo -e "\e[36m    create rule to create symbolic link\e[0m";
        tar -ravf $BACKUP_FILE -C / etc/udev/rules.d/99-gps.rules
        cat << EOF | sudo tee /etc/udev/rules.d/99-gps.rules &>/dev/null
## Stratum1
KERNEL==\"pps0\",SYMLINK+=\"gpspps0\"
KERNEL==\"ttyAMA0\", SYMLINK+=\"gps0\"
EOF
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

#########################################
# https://www.raspberrypi.org/documentation/configuration/config-txt.md
# https://github.com/raspberrypi/firmware/tree/master/boot/overlays
## Stratum1

# gps + pps + ntp settings

#Name:   pps-gpio
#Info:   Configures the pps-gpio (pulse-per-second time signal via GPIO).
#Load:   dtoverlay=pps-gpio,<param>=<val>
#Params: gpiopin                 Input GPIO (default "18")
#        assert_falling_edge     When present, assert is indicated by a falling
#                                edge, rather than by a rising edge
# dtoverlay=pps-gpio,gpiopin=4,assert_falling_edge
dtoverlay=pps-gpio,gpiopin=4

#Name:   pi3-disable-bt
#Info:   Disable Pi3 Bluetooth and restore UART0/ttyAMA0 over GPIOs 14 & 15
#        N.B. To disable the systemd service that initialises the modem so it
#        doesn't use the UART, use 'sudo systemctl disable hciuart'.
#Load:   dtoverlay=pi3-disable-bt
#Params: <None>
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
    sudo systemctl stop ntp.service &>/dev/null;
    sudo systemctl disable ntp.service &>/dev/null;
}



######################################################################
######################################################################
install_chrony() {
    echo -e "\e[32minstall_chrony()\e[0m";

    sudo apt-get -y install chrony;
}


######################################################################
setup_chrony() {
    echo -e "\e[32msetup_chrony()\e[0m";

    sudo systemctl stop chronyd.service;

    tar -ravf $BACKUP_FILE -C / etc/chrony/chrony.conf
    cat << EOF | sudo tee /etc/chrony/chrony.conf &>/dev/null
# /etc/chrony/chrony.conf
## Stratum1

# https://chrony.tuxfamily.org/documentation.html
# http://www.catb.org/gpsd/gpsd-time-service-howto.html#_feeding_chrony_from_gpsd
# gspd is looking for
# /var/run/chrony.pps0.sock
# /var/run/chrony.ttyAMA0.sock


# Welcome to the chrony configuration file. See chrony.conf(5) for more
# information about usuable directives.


######################################################################
######################################################################
#
## SHM(0), gpsd: NMEA data from shared memory provided by gpsd
#refclock  SHM 0  refid NMEA  precision 1e-3  offset 0.5  delay 0.2  poll 3  trust  require
#
## PPS: /dev/pps0: Kernel-mode PPS ref-clock for the precise seconds
#refclock  PPS /dev/pps0  refid PPS  precision 1e-9  lock NMEA  poll 3  trust  prefer
#
## SHM(2), gpsd: PPS data from shared memory provided by gpsd
#refclock  SHM 2  refid PPSx  precision 1e-9  poll 3  trust
#
## SOCK, gpsd: PPS data from socket provided by gpsd
#refclock  SOCK /var/run/chrony.pps0.sock  refid PPSy  precision 1e-9  poll 3  trust
#
######################################################################
######################################################################

# https://chrony.tuxfamily.org/faq.html#_using_a_pps_reference_clock
# SHM(0), gpsd: NMEA data from shared memory provided by gpsd
refclock  SHM 0  refid NMEA  precision 1e-1  offset 0.6  delay 0.2  noselect
#  require

# PPS: /dev/pps0: Kernel-mode PPS ref-clock for the precise seconds
refclock  PPS /dev/pps0  refid PPS  precision 1e-9  lock NMEA  noselect
#  prefer
#  trust

# SHM(2), gpsd: PPS data from shared memory provided by gpsd
refclock  SHM 2  refid PPSx  precision 1e-8  prefer
#  trust
#  noselect

# SOCK, gpsd: PPS data from socket provided by gpsd
refclock  SOCK /var/run/chrony.pps0.sock  refid PPSy  precision 1e-7
#  prefer
#  trust
#  noselect

######################################################################
######################################################################

# any NTP clients are allowed to access the NTP server.
allow

# allows to appear synchronised to NTP clients, even when it is not.
local


# Stratum1 Servers
# https://www.meinbergglobal.com/english/glossary/public-time-server.htm
#
## Physikalisch-Technische Bundesanstalt (PTB), Braunschweig, Germany
#server  ptbtime1.ptb.de  iburst  noselect
#server  ptbtime2.ptb.de  iburst  noselect
#server  ptbtime3.ptb.de  iburst  noselect
#
## Royal Observatory of Belgium
#server  ntp1.oma.be  iburst  noselect
#server  ntp2.oma.be  iburst  noselect

# Other NTP Servers
#pool  de.pool.ntp.org  iburst  noselect


# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Uncomment the following line to turn logging on.
#log tracking measurements statistics

# Log files location.
logdir /var/log/chrony

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# This directive tells 'chronyd' to parse the 'adjtime' file to find out if the
# real-time clock keeps local time or UTC. It overrides the 'rtconutc' directive.
hwclockfile /etc/adjtime

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
#makestep 1 3

makestep 0.2 -1
EOF
    sudo systemctl restart chronyd.service;
}


######################################################################
disable_chrony() {
    echo -e "\e[32mdisable_chrony()\e[0m";
    sudo systemctl stop chronyd.service &>/dev/null;
    sudo systemctl disable chronyd.service &>/dev/null;
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
    grep -q Stratum1 /etc/samba/smb.conf &>/dev/null || {
        echo -e "\e[36m  setup samba\e[0m";
        sudo systemctl stop smb.service;

        tar -ravf $BACKUP_FILE -C / etc/samba/smb.conf
        #sudo sed -i /etc/samba/smb.conf -n -e "1,/#======================= Share Definitions =======================/p";
        cat << EOF | sudo tee -a /etc/samba/smb.conf &>/dev/null
## Stratum1

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

    grep -q Stratum1 /etc/dhcpcd.conf || {
        echo -e "\e[36m    setup dhcpcd.conf\e[0m";
        tar -ravf $BACKUP_FILE -C / etc/dhcpcd.conf
        cat << EOF | sudo tee -a /etc/dhcpcd.conf &>/dev/null
## Stratum1
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
## test commands
######################################################################
#dmesg | grep pps
#sudo ppstest /dev/pps0
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
#chronyc sources
#chronyc sourcestats
#chronyc tracking
#watch -n 10 -p chronyc -m sources tracking
######################################################################


handle_timezone

handle_update

handle_gps
handle_pps

disable_timesyncd;
disable_ntp;

install_chrony;
setup_chrony;

handle_samba
handle_dhcpcd


######################################################################
echo -e "\e[32mDone.\e[0m";
echo -e "\e[1;31mPlease reboot\e[0m";
