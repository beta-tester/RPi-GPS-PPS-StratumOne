#!/bin/bash

######################################################################
# 2017-09-07-raspbian-stretch-lite

#USE_TIME_SERVICE=ntp
USE_TIME_SERVICE=chrony

##################################################################
NTP_VER=4.2.8p10
##################################################################


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
    && echo -e "\e[32mupdate...\e[0m" && sudo apt-get update \
    && echo -e "\e[32mupgrade...\e[0m" && sudo apt-get -y upgrade \
    && echo -e "\e[32mdist-upgrade...\e[0m" && sudo apt-get -y dist-upgrade \
    && echo -e "\e[32mautoremove...\e[0m" && sudo apt-get -y --purge autoremove \
    && echo -e "\e[32mautoclean...\e[0m" && sudo apt-get autoclean \
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
        sudo sh -c "cat << EOF  > /boot/config.txt
# /boot/config.txt
# https://www.raspberrypi.org/documentation/configuration/config-txt.md
## Stratum1

[all]
max_usb_current=1
force_turbo=1

disable_overscan=1
hdmi_force_hotplug=1
config_hdmi_boost=4

#hdmi_ignore_cec_init=1
cec_osd_name=Stratum1

#########################################
# standard resolution
hdmi_drive=2

#########################################
# custom resolution
# 4k@24Hz or 25Hz custom DMT - mode
#gpu_mem=128
#hdmi_group=2
#hdmi_mode=87
#hdmi_pixel_freq_limit=400000000
#max_framebuffer_width=3840
#max_framebuffer_height=2160
#
#    #### implicit timing ####
#    hdmi_cvt 3840 2160 24
#    #hdmi_cvt 3840 2160 25
#
#    #### explicit timing ####
#    #hdmi_ignore_edid=0xa5000080
#    #hdmi_timings=3840 1 48 32 80 2160 1 3 5 54 0 0 0 24 0 211190000 3
#    ##hdmi_timings=3840 1 48 32 80 2160 1 3 5 54 0 0 0 25 0 220430000 3
#    #framebuffer_width=3840
#    #framebuffer_height=2160

# gps + pps + ntp settings
# https://github.com/raspberrypi/firmware/tree/master/boot/overlays
#Name:   pps-gpio
#Info:   Configures the pps-gpio (pulse-per-second time signal via GPIO).
#Load:   dtoverlay=pps-gpio,<param>=<val>
#Params: gpiopin                 Input GPIO (default "18")
#        assert_falling_edge     When present, assert is indicated by a falling
#                                edge, rather than by a rising edge
# dtoverlay=pps-gpio,gpiopin=4,assert_falling_edge
dtoverlay=pps-gpio,gpiopin=4
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
handle_ntp_tools() {
    echo -e "\e[32mhandle_ntp_tools()\e[0m";

    echo -e "\e[36m    install ntp tools\e[0m";
    sudo apt-get -y install ntpstat ntpdate;
}


######################################################################
install_ntp() {
    echo -e "\e[32minstall_ntp()\e[0m";

    sudo apt-get -y install ntp;
}


######################################################################
compile_ntp() {
    echo -e "\e[32mcompile_ntp()\e[0m";

    ######################################################################
    # http://www.linuxfromscratch.org/blfs/view/svn/basicnet/ntp.html
    # https://wiki.polaire.nl/doku.php?id=compile_ntp_on_centos7
    # https://anonscm.debian.org/git/pkg-ntp/pkg-ntp.git/
    echo -e "\e[36m  compile ntp with PPS support\e[0m";
    sudo systemctl stop ntp.service;
    sudo systemctl disable ntp.service;

    ## do not remove the installes ntp package, to use its efault settings and scripts as template
    sudo apt-mark hold ntp;
    ##sudo apt-get -y --auto-remove purge ntp;

    # download and compile ntp from source
    sudo apt-get -y install libcap-dev libssl-dev;
    wget http://archive.ntp.org/ntp4/ntp-4.2/ntp-$NTP_VER.tar.gz;
    tar xvfz ntp-$NTP_VER.tar.gz;
    cd ntp-$NTP_VER/;

#    sudo groupadd  ntp
#    sudo useradd  -c "Network Time Protocol"  -d /var/lib/ntp  -g ntp  -s /bin/false  ntp

#    sed -e "s/https/http/"  -e 's/"(\\S+)"/"?([^\\s"]+)"?/'  -i scripts/update-leap/update-leap.in

    ./configure CFLAGS="-O2 -g -fPIC" \
                --prefix=/usr         \
                --bindir=/usr/sbin    \
                --sysconfdir=/etc     \
                --docdir=/usr/share/doc/ntp-$NTP_VER \
                --enable-linuxcaps \
                --enable-ATOM \
                --with-lineeditlibs=readline
    make;
    sudo make install;
    sudo install -v  -o ntp  -g ntp  -d /var/lib/ntp;

    sudo cp /usr/sbin/ntpq     /usr/bin/ntpq
    sudo cp /usr/sbin/ntpsweep /usr/bin/ntpsweep
    sudo cp /usr/sbin/ntpdc    /usr/bin/ntpdc
    sudo cp /usr/sbin/ntptrace /usr/bin/ntptrace

#    sudo sh -c "cat << EOF  > /etc/systemd/system/ntp.service
#[Unit]
#Description=Network Time Service
#After=syslog.target ntpdate.service sntp.service
#Conflicts=systemd-timesyncd.service
#
#[Service]
#Type=forking
#ExecStart=/usr/local/sbin/ntpd -g -u ntp:ntp
#PrivateTmp=true
#
#[Install]
#WantedBy=multi-user.target
#EOF";

    sudo systemctl enable ntp.service;
    sudo systemctl restart ntp.service;
}


######################################################################
setup_ntp() {
    echo -e "\e[32msetup_ntp()\e[0m";

    sudo systemctl stop ntp.service;
    sudo sh -c "cat << EOF  > /etc/ntp.conf
# /etc/ntp.conf
## Stratum1

driftfile /var/lib/ntp/ntp.drift

# Enable this if you want statistics to be logged.
statsdir /var/log/ntpstats/
statistics loopstats peerstats clockstats
filegen  loopstats  file loopstats  type week  enable
filegen  peerstats  file peerstats  type week  enable
filegen  clockstats  file clockstats  type week  enable


# 20; NMEA(0), /dev/gpsu, /dev/gpsppsu, /dev/gpsu: Generic NMEA GPS Receiver
# http://doc.ntp.org/current-stable/drivers/driver20.html
#server  127.127.20.0  mode 287  prefer  true
#fudge   127.127.20.0  refid NMEA  time1 -0.0045  time2 0.450  flag1 1
# time1 time:     Specifies the PPS time offset calibration factor, in seconds and fraction, with default 0.0.
# time2 time:     Specifies the serial end of line time offset calibration factor, in seconds and fraction, with default 0.0.
# stratum number: Specifies the driver stratum, in decimal from 0 to 15, with default 0.
# refid string:   Specifies the driver reference identifier, an ASCII string from one to four characters, with default GPS.
# flag1 0 | 1:    Disable PPS signal processing if 0 (default); enable PPS signal processing if 1.
# flag2 0 | 1:    If PPS signal processing is enabled, capture the pulse on the rising edge if 0 (default); capture on the falling edge if 1.
# flag3 0 | 1:    If PPS signal processing is enabled, use the ntpd clock discipline if 0 (default); use the kernel discipline if 1.
# flag4 0 | 1:    Obscures location in timecode: 0 for disable (default), 1 for enable.


# 22; PPS(0), gpsd: /dev/pps0: Kernel-mode PPS ref-clock for the precise seconds
# http://doc.ntp.org/current-stable/drivers/driver22.html
server  127.127.22.0  minpoll 3  maxpoll 3  prefer  true
fudge   127.127.22.0  refid PPS  time1 -0.0045
# time1 time:     Specifies the time offset calibration factor, in seconds and fraction, with default 0.0.
# time2 time:     Not used by this driver.
# stratum number: Specifies the driver stratum, in decimal from 0 to 15, with default 0.
# refid string:   Specifies the driver reference identifier, an ASCII string from one to four characters, with default PPS.
# flag1 0 | 1:    Not used by this driver.
# flag2 0 | 1:    Specifies PPS capture on the rising (assert) pulse edge if 0 (default) or falling (clear) pulse edge if 1. Not used under Windows - if the special serialpps.sys serial port driver is installed then the leading edge will always be used.
# flag3 0 | 1:    Controls the kernel PPS discipline: 0 for disable (default), 1 for enable. Not used under Windows - if the special serialpps.sys serial port driver is used then kernel PPS will be available and used.
# flag4 0 | 1:    Record a timestamp once for each second if 1. Useful for constructing Allan deviation plots.


# 28; SHM(0), gpsd: NMEA data from shared memory provided by gpsd
# # http://doc.ntp.org/current-stable/drivers/driver28.html
server  127.127.28.0  minpoll 4  maxpoll 5  prefer  true
fudge   127.127.28.0  refid SHM0  time1 0.450  stratum 10  flag1 1
# time1 time:     Specifies the time offset calibration factor, in seconds and fraction, with default 0.0.
# time2 time:     Maximum allowed difference between remote and local clock, in seconds. Values  less 1.0 or greater 86400.0 are ignored, and the default value of 4hrs (14400s) is used instead. See also flag 1.
# stratum number: Specifies the driver stratum, in decimal from 0 to 15, with default 0.
# refid string:   Specifies the driver reference identifier, an ASCII string from one to four characters, with default SHM.
# flag1 0 | 1:    Skip the difference limit check if set. Useful for systems where the RTC backup cannot keep the time over long periods without power and the SHM clock must be able to force long-distance initial jumps. Check the difference limit if cleared (default).
# flag2 0 | 1:    Not used by this driver.
# flag3 0 | 1:    Not used by this driver.
# flag4 0 | 1:    If flag4 is set, clockstats records will be written when the driver is polled.


# 28; SHM(2), gpsd: PPS data from shared memory provided by gpsd
# # http://doc.ntp.org/current-stable/drivers/driver28.html
server  127.127.28.2  minpoll 3  maxpoll 3  true
fudge   127.127.28.2  refid SHM2  stratum 1


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
#server  ntp1.sp.se  iburst  noselect
#server  ntp2.sp.se  iburst  noselect


# You do need to talk to an NTP server or two (or three).
#server ntp.your-provider.example

# pool.ntp.org maps to about 1000 low-stratum NTP servers.  Your server will
# pick a different set every time it starts up.  Please consider joining the
# pool: <http://www.pool.ntp.org/join.html>
#server  0.debian.pool.ntp.org  iburst
#server  1.debian.pool.ntp.org  iburst
#server  2.debian.pool.ntp.org  iburst
#server  3.debian.pool.ntp.org  iburst


# Access control configuration; see /usr/share/doc/ntp-doc/html/accopt.html for
# details.  The web page <http://support.ntp.org/bin/view/Support/AccessRestrictions>
# might also be helpful.
#
# Note that restrict applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but do not allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1

# Clients from this (example!) subnet have unlimited access, but only if
# cryptographically authenticated.
#restrict 192.168.123.0 mask 255.255.255.0 notrust


# If you want to provide time to your local subnet, change the next line.
# (Again, the address is an example only.)
#broadcast 192.168.123.255

# If you want to listen to time broadcasts on your local subnet, de-comment the
# next lines.  Please do this only if you trust everybody on the network!
#disable auth
#broadcastclient
EOF";
    sudo systemctl restart ntp.service;
}


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
        sudo sed -i /etc/samba/smb.conf -n -e "1,/#======================= Share Definitions =======================/p";
        sudo sh -c "cat << EOF  >> /etc/samba/smb.conf
[global]
# https://www.samba.org/samba/security/CVE-2017-14746.html
server min protocol = SMB2

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
#  path = /var/log/ntpstats/
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
#ntpq -crv -pn
#watch -n 10 "sh -c 'ntpstat; ntpq -p -crv;'"
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

if [ "$USE_TIME_SERVICE" == "chrony" ]; then
    disable_ntp;
    install_chrony;
    setup_chrony;
else
    disable_chrony;
    handle_ntp_tools;
    install_ntp;
    if ! ( echo $(ntpd --version;) | grep -q "ntpd $NTP_VER"; ); then
        ntpd --version;
        #compile_ntp
    fi
    setup_ntp;
fi


handle_samba
handle_dhcpcd


######################################################################
echo -e "\e[32mDone.\e[0m";
echo -e "\e[1;31mPlease reboot\e[0m";
