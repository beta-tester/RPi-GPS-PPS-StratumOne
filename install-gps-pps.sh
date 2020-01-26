#!/bin/bash

######################################################################
# 2019-09-26-raspbian-buster-lite


##################################################################
# if a GPS module is already installed and is giving GPS feed on the GPIO-serial port,
# it can generate error messages to the console, because the kernel try to interprete this as commands from the boot console
sudo systemctl stop serial-getty@ttyAMA0.service;
sudo systemctl disable serial-getty@ttyAMA0.service;
sudo sed -i -e "s/console=serial0,115200//" /boot/cmdline.txt;


######################################################################
handle_locale() {
    echo -e "\e[32mhandle_locale()\e[0m";

    echo -e "\e[36m    prepare locale to nothing (default:C.UTF-8)\e[0m";
    export LC_TIME=C.UTF-8;
    export LC_MONETARY=C.UTF-8;
    export LC_ADDRESS=C.UTF-8;
    export LC_TELEPHONE=C.UTF-8;
    export LC_NAME=C.UTF-8;
    export LC_MEASUREMENT=C.UTF-8;
    export LC_IDENTIFICATION=C.UTF-8;
    export LC_NUMERIC=C.UTF-8;
    export LC_PAPER=C.UTF-8;
    export LC_CTYPE=C.UTF-8;
    export LC_MESSAGES=C.UTF-8;
    export LC_ALL=C.UTF-8;
    export LANG=C.UTF-8;
    export LANGUAGE=C.UTF-8;
    sudo sed -i -e "s/^en_GB.UTF-8 UTF-8/\# en_GB.UTF-8 UTF-8/" /etc/locale.gen;
    sudo LC_ALL=C.UTF-8 locale-gen --purge;
    sudo sh -c "cat << EOF  > /etc/default/locale
# /etc/default/locale
LANG=C.UTF-8
LANGUAGE=C.UTF-8
LC_ALL=C.UTF-8
EOF";
}

######################################################################
handle_timezone() {
    echo -e "\e[32mhandle_timezone()\e[0m";

    echo -e "\e[36m    prepare timezone to Etc/UTC\e[0m";
    sudo sh -c "echo 'Etc/UTC' > /etc/timezone";
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
    # specific to 2017-08-16-raspbian-stretch-lite
    echo -e "\e[36m    make boot quiet to serial port: serial0\e[0m";
    sudo sed -i -e "s/console=serial0,115200//" /boot/cmdline.txt;
    sudo systemctl stop serial-getty@ttyAMA0.service;
    sudo systemctl disable serial-getty@ttyAMA0.service;

    ##################################################################
    echo -e "\e[36m    install gpsd\e[0m";
    sudo apt-get -y install gpsd gpsd-clients;

    ##################################################################
    echo -e "\e[36m    setup gpsd\e[0m";
    sudo systemctl stop gpsd.socket;
    sudo systemctl stop gpsd.service;
    sudo sh -c "cat << EOF  > /etc/default/gpsd
# /etc/default/gpsd
## Stratum1
START_DAEMON=\"true\"
GPSD_OPTIONS=\"-n\"
DEVICES=\"/dev/ttyAMA0 /dev/pps0\"
USBAUTO=\"false\"
GPSD_SOCKET=\"/var/run/gpsd.sock\"
EOF";
    sudo systemctl restart gpsd.service;
    sudo systemctl restart gpsd.socket;

    ##################################################################
    grep -q Stratum1 /lib/systemd/system/gpsd.socket 2> /dev/null || {
        echo -e "\e[36m    fix gpsd to listen to all connection requests\e[0m";
        sudo sed /lib/systemd/system/gpsd.socket -i -e "s/ListenStream=127.0.0.1:2947/ListenStream=0.0.0.0:2947/";
        sudo sh -c "cat << EOF  >> /lib/systemd/system/gpsd.socket
;; Stratum1
EOF";
    }

    grep -q Stratum1 /etc/rc.local 2> /dev/null || {
        echo -e "\e[36m    tweak GPS device at start up\e[0m";
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
        sudo rm -f /etc/dhcp/dhclient-exit-hooks.d/ntp;
    }

    [ -f "/etc/udev/rules.d/99-gps.rules" ] || {
        echo -e "\e[36m    create rule to create symbolic link\e[0m";
        sudo sh -c "cat << EOF  > /etc/udev/rules.d/99-gps.rules
## Stratum1
KERNEL==\"pps0\",SYMLINK+=\"gpspps0\"
KERNEL==\"ttyAMA0\", SYMLINK+=\"gps0\"
EOF";
    }
}


######################################################################
handle_pps() {
    echo -e "\e[32mhandle_pps()\e[0m";

    ##################################################################
    echo -e "\e[36m    install PPS tools\e[0m";
    sudo apt-get -y install pps-tools;

    ##################################################################
    grep -q pps-gpio /boot/config.txt 2> /dev/null || {
        echo -e "\e[36m    setup config.txt for PPS\e[0m";
        sudo sh -c "cat << EOF  >> /boot/config.txt
# /boot/config.txt

max_usb_current=1
#force_turbo=1

disable_overscan=1
hdmi_force_hotplug=1
config_hdmi_boost=4

#hdmi_ignore_cec_init=1
cec_osd_name=Stratum1

#########################################
# standard resolution
hdmi_drive=2


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
EOF";
    }

    ##################################################################
    grep -q pps-gpio /etc/modules 2> /dev/null || {
        echo -e "\e[36m    add pps-gpio to modules for PPS\e[0m";
        sudo sh -c "echo 'pps-gpio' >> /etc/modules";
    }
}


######################################################################
######################################################################
disable_ntp() {
    echo -e "\e[32mdisable_ntp()\e[0m";
    sudo systemctl stop ntp.service 1>/dev/null 2>/dev/null;
    sudo systemctl disable ntp.service 1>/dev/null 2>/dev/null;
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
    sudo sh -c "cat << EOF  > /etc/chrony/chrony.conf
# /etc/chrony/chrony.conf
## Stratum1

# https://chrony.tuxfamily.org/documentation.html
# http://www.catb.org/gpsd/gpsd-time-service-howto.html#_feeding_chrony_from_gpsd
# gspd is looking for
# /var/run/chrony.pps0.sock
# /var/run/chrony.ttyAMA0.sock


# Welcome to the chrony configuration file. See chrony.conf(5) for more
# information about usuable directives.


# PPS: /dev/pps0: Kernel-mode PPS ref-clock for the precise seconds
refclock  PPS /dev/pps0  refid PPS  precision 1e-9  lock NMEA  poll 3  trust  prefer

# SHM(2), gpsd: PPS data from shared memory provided by gpsd
refclock  SHM 2  refid PPSx  precision 1e-9  poll 3  trust

# SOCK, gpsd: PPS data from socket provided by gpsd
refclock  SOCK /var/run/chrony.pps0.sock  refid PPSy  precision 1e-9  poll 3  trust

# SHM(0), gpsd: NMEA data from shared memory provided by gpsd
refclock  SHM 0  refid NMEA  precision 1e-3  offset 0.5  delay 0.2  poll 3  trust  require

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
#
## Unizeto Technologies S.A., Szczecin, Polska
#server  ntp.certum.pl  iburst  noselect
#
## SP Swedish National Testing and Research Institute, Boras, Sweden
#server  ntp2.sp.se  iburst  noselect

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
makestep 1 3
EOF";
    sudo systemctl restart chronyd.service;
}


######################################################################
disable_chrony() {
    echo -e "\e[32mdisable_chrony()\e[0m";
    sudo systemctl stop chronyd.service 1>/dev/null 2>/dev/null;
    sudo systemctl disable chronyd.service 1>/dev/null 2>/dev/null;
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
    grep -q Stratum1 /etc/samba/smb.conf 2> /dev/null || {
        echo -e "\e[36m  setup samba\e[0m";
        sudo systemctl stop smb.service;
        #sudo sed -i /etc/samba/smb.conf -n -e "1,/#======================= Share Definitions =======================/p";
        sudo sh -c "cat << EOF  >> /etc/samba/smb.conf
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
EOF";
        sudo systemctl restart smbd.service;
    }
}


######################################################################
handle_dhcpcd() {
    echo -e "\e[32mhandle_dhcpcd()\e[0m";

    grep -q Stratum1 /etc/dhcpcd.conf || {
        echo -e "\e[36m    setup dhcpcd.conf\e[0m";
        sudo sh -c "cat << EOF  >> /etc/dhcpcd.conf
## Stratum1
#interface eth0
#static ip_address=192.168.1.161/24
#static routers=192.168.1.1
#static domain_name_servers=192.168.1.1
EOF";
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


handle_locale
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
