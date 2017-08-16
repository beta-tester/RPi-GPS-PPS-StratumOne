#!/bin/bash


######################################################################
{
echo -e "\e[32mprepare locale to nothing (default:en)\e[0m";
export LC_TIME=;
export LC_MONETARY=;
export LC_ADDRESS=;
export LC_TELEPHONE=;
export LC_NAME=;
export LC_MEASUREMENT=;
export LC_IDENTIFICATION=;
export LC_NUMERIC=;
export LC_PAPER=;
export LC_CTYPE=;
export LC_MESSAGES=;
export LC_ALL=;
export LANG=;
export LANGUAGE=;
sudo sed -i -e "s/^en_GB.UTF-8 UTF-8/\# en_GB.UTF-8 UTF-8/" /etc/locale.gen;
sudo locale-gen --purge;
sudo sh -c "echo '# /etc/default/locale
LANG=
LANGUAGE=
' > /etc/default/locale";
}

{
echo -e "\e[32mprepare timezone to Etc/UTC\e[0m";
sudo sh -c "echo 'Etc/UTC' > /etc/timezone";
sudo dpkg-reconfigure -f noninteractive tzdata;
}

######################################################################
sudo sync \
&& echo -e "\e[32mupdate...\e[0m" && sudo apt-get update \
&& echo -e "\e[32mupgrade...\e[0m" && sudo apt-get -y upgrade \
&& echo -e "\e[32mdist-upgrade...\e[0m" && sudo apt-get -y dist-upgrade \
&& echo -e "\e[32mautoremove...\e[0m" && sudo apt-get -y --purge autoremove \
&& echo -e "\e[32mautoclean...\e[0m" && sudo apt-get autoclean \
&& echo -e "\e[32mDone.\e[0m" \
&& sudo sync;


################################################################################
{
echo -e "\e[32mprepare GPS\e[0m";
# up to 2016-02-26-raspbian-jessie-lite.img
echo -e "\e[32mmake boot quiet to serial port: ttyAMA0\e[0m";
sudo sed -i -e "s/console=ttyAMA0,115200//" /boot/cmdline.txt;
sudo systemctl stop serial-getty@ttyAMA0.service;
sudo systemctl disable serial-getty@ttyAMA0.service;
}

{
# since 2016-03-18-raspbian-jessie-lite.img
echo -e "\e[32mmake boot quiet to serial port: serial0\e[0m";
sudo sed -i -e "s/console=serial0,115200//" /boot/cmdline.txt;
sudo systemctl stop serial-getty@serial0.service;
sudo systemctl disable serial-getty@serial0.service;
}

################################################################################
{
echo -e "\e[32minstall gpsd\e[0m";
sudo apt-get -y install gpsd gpsd-clients;
}

{
echo -e "\e[32msetup gpsd\e[0m";
sudo systemctl stop gpsd.service;
sudo sh -c "echo '# /etc/default/gpsd
## Stratum1
START_DAEMON=\"true\"
GPSD_OPTIONS=\"-n\"
DEVICES=\"/dev/ttyAMA0\"
USBAUTO=\"false\"
GPSD_SOCKET=\"/var/run/gpsd.sock\"
' > /etc/default/gpsd";
sudo systemctl restart gpsd.service;
}

grep -q Stratum1 /lib/systemd/system/gpsd.socket 2> /dev/null || {
echo -e "\e[32mfix gpsd to listen not only to localhost connections\e[0m";
sudo sed /lib/systemd/system/gpsd.socket -i -e "s/ListenStream=127.0.0.1:2947/ListenStream=0.0.0.0:2947/";
sudo sh -c "echo ';; Stratum1
' >> /lib/systemd/system/gpsd.socket";
}

grep -q Stratum1 /etc/rc.local 2> /dev/null || {
echo -e "\e[32mtweak GPS device at start up\e[0m";
sudo sed /etc/rc.local -i -e "s/^exit 0$//";
printf "## Stratum1
sudo systemctl stop gpsd.service
stty -F /dev/ttyAMA0 9600
## prepare GPS device to
## 115200baud io rate,
## 10 Hz update interval
#printf \x27\x24PMTK251,115200*1F\x5Cr\x5Cn\x27 \x3E /dev/ttyAMA0
#stty -F /dev/ttyAMA0 115200
#printf \x27\x24PMTK220,100*2F\x5Cr\x5Cn\x27 \x3E /dev/ttyAMA0
sudo systemctl restart gpsd.service
gpspipe -r -n 1 &

exit 0
" | sudo tee -a /etc/rc.local > /dev/null;
}

[ -f "/etc/dhcp/dhclient-exit-hooks.d/ntp" ] && {
sudo rm -f /etc/dhcp/dhclient-exit-hooks.d/ntp;
}

[ -f "/etc/udev/rules.d/99-gps.rules" ] || {
sudo sh -c "echo '## Stratum1
KERNEL==\"pps0\",SYMLINK+=\"gpspps0\"
KERNEL==\"ttyAMA0\", SYMLINK+=\"gps0\"' > /etc/udev/rules.d/99-gps.rules";
}

################################################################################
{
echo -e "\e[32minstall PPS tools\e[0m";
sudo apt-get -y install pps-tools;
}

grep -q pps-gpio /boot/config.txt 2> /dev/null || {
echo -e "\e[32msetup config.txt for PPS\e[0m";
sudo sh -c "echo '# /boot/config.txt
# https://www.raspberrypi.org/documentation/configuration/config-txt.md
## Stratum1

[pi0]

[pi1]
#arm_freq=1000
#core_freq=500
#sdram_freq=600
#over_voltage=6

[pi2]
#arm_freq=1000
#core_freq=500
#sdram_freq=500
#over_voltage=2

[pi3]


[all]
max_usb_current=1
force_turbo=1

disable_overscan=1
hdmi_force_hotplug=1
config_hdmi_boost=4
hdmi_drive=2
cec_osd_name=Stratum1

# gps + pps + ntp settings
# https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/overlays/README
dtoverlay=pps-gpio,gpiopin=4
' > /boot/config.txt";
}

grep -q pps-gpio /etc/modules 2> /dev/null || {
echo -e "\e[32madd pps-gpio to modules for PPS\e[0m";
sudo sh -c "echo 'pps-gpio' >> /etc/modules";
}


################################################################################
{
echo -e "\e[32minstall ntp\e[0m";
sudo apt-get -y install ntp ntpstat ntpdate;
}

################################################################################
{
echo -e "\e[32mcompile ntp with PPS support\e[0m";
sudo systemctl stop ntp.service;
sudo apt-mark hold ntp;
sudo apt-get -y install libcap-dev libssl-dev;
wget http://archive.ntp.org/ntp4/ntp-4.2/ntp-4.2.8p10.tar.gz;
tar xvfz ntp-4.2.8p10.tar.gz;
cd ntp-4.2.8p10/;
./configure --enable-linuxcaps;
make;
sudo make install;
sudo cp /usr/local/bin/ntp* /usr/bin/;
sudo cp /usr/local/sbin/ntp* /usr/sbin/;
sudo systemctl restart ntp.service;
}

################################################################################
{
echo -e "\e[32msetup ntp (with gpsd, pps)\e[0m";
sudo systemctl stop ntp.service;
sudo sh -c "echo '# /etc/ntp.conf
## Stratum1

driftfile /var/lib/ntp/ntp.drift

# Enable this if you want statistics to be logged.
statsdir /var/log/ntpstats/
statistics loopstats peerstats clockstats
filegen  loopstats  file loopstats  type week  enable
filegen  peerstats  file peerstats  type week  enable
filegen  clockstats  file clockstats  type week  enable


#enable stats
enable pps


# PPS(0), gpsd: /dev/pps0: Kernel-mode PPS ref-clock for the precise seconds
# http://doc.ntp.org/current-stable/drivers/driver22.html
server  127.127.22.0  minpoll 3  maxpoll 3  prefer  true
fudge   127.127.22.0  refid PPS  time1 -0.0045  flag3 1  # enable kernel PPS discipline

# SHM(0), gpsd: Server from shared memory provided by gpsd
# # http://doc.ntp.org/current-stable/drivers/driver28.html
server  127.127.28.0  minpoll 4  maxpoll 5  prefer  true
fudge   127.127.28.0  refid NMEA  time1 0.450  stratum 10  flag1 1  #9600baud, 1Hz: skip diff limit


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
# Note that \"restrict\" applies to both servers and clients, so a configuration
# that might be intended to block requests from certain clients could also end
# up blocking replies from your own upstream servers.

# By default, exchange time with everybody, but don't allow configuration.
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
' > /etc/ntp.conf";
sudo systemctl restart ntp.service;
}

######################################################################
echo -e "\e[32minstall samba\e[0m";
sudo apt-get -y install samba;

[ -d "/media/share" ] || {
echo -e "\e[32create share folder\e[0m";
sudo mkdir -p /media/share;
}

grep -q Stratum1 /etc/samba/smb.conf 2> /dev/null || {
echo -e "\e[32msetup samba\e[0m";
sudo sed -i /etc/samba/smb.conf -n -e "1,/#======================= Share Definitions =======================/p";
sudo sh -c "echo '
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
  force create mask = 0644
  force directory mask = 0755
  force user = root
  force group = root

  [ntpstats]
  comment = NTP Statistics
  path = /var/log/ntpstats/
  public = yes
  only guest = yes
  browseable = yes
  read only = yes
  writeable = no
  create mask = 0644
  directory mask = 0755
  force create mask = 0644
  force directory mask = 0755
  force user = root
  force group = root
' >> /etc/samba/smb.conf";
sudo systemctl restart smbd.service;
}


######################################################################
grep -q eth0 /etc/dhcpcd.conf || {
echo -e "\e[32msetup dhcpcd.conf\e[0m";
sudo sh -c "echo '## Stratum1
#interface eth0
#static ip_address=192.168.100.161/24
#static routers=192.168.100.23
#static domain_name_servers=192.168.100.23
' >> /etc/dhcpcd.conf";
}


################################################################################
#sudo gpsd /dev/ttyAMA0 -n -F /var/run/gpsd.sock
#sudo killall gpsd
#sudo dpkg-reconfigure gpsd
#minicom -b 9600 -o -D /dev/ttyAMA0
#sudo ppstest /dev/pps0
#ntpq -crv -pn
################################################################################

echo -e "\e[32mDone.\e[0m";
echo -e "\e[1;31mPlease reboot\e[0m";
