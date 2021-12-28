# RPi-GPS-PPS-StratumOne

setup a Raspberry Pi as an Stratum One NTP server.<br />
it is a private project i have made for myself.<br />
i did not keep an eye on network security.

**the script will override some existing configurations**<br />
(a backup of the changed configuration files will be stored to **backup.tar.xz**)

**USE IT AT YOUR OWN RISK**

**Please give me a '_Star_', if you find that project useful.**

### overview schematic:
```
                     ╔═══╗       ╔══════╗         ╔══════╗  GPS-Antenna
                   ──╢ s ║       ║RPi as╟RX───────╢GPS-  ║    ═╪═
                     ║ w ║       ║NTP-  ╟TX───────╢module║     │
                     ║ i ║       ║server║         ╠═══╗  ║     │
       ╔══════╗      ║ t ╟───eth0╢      ╟GPIO#4───╢PPS║  ╟─────┘
       ║ RPi  ╟──────╢ c ║       ║      ║         ╚═══╩══╝
       ╚══════╝   ┌──╢ h ╟──┐    ║      ╟GPIO#7╴╴╴╢PPS║  ╟╴╴
                  │  ╚═══╝  │    ╚══════╝         ╚═══╩══╝
               ╔══╧══╗   ╔══╧══╗
               ║ PC1 ║   ║ PC2 ║
               ╚═════╝   ╚═════╝
```
### overview: path of time source
(without external NTP servers)
```
╔═══════╗       ╔══════════════════╗
║ GPS   ╫──RX───╫──┐ KERNEL        ║
║ ╔═════╣       ║  │               ║                                     ╔══════════════
║ ║NMEA─╫──TX───╫─[+]─/dev/ttyAMA0─╫────────┬───NMEA──x                  ║ CHRONY
║ ╠═════╣       ║                  ║        │                            ║
║ ║ PPS─╫─GPIO4─╫─────/dev/pps0────╫──────┬─)────────────────────────────╫──[+]────PPS0
╚═╩═════╝      ╴╫╴╴┐               ║      │ │                            ║   │
  ╠═════╣      ╴╫╴[+]╴/dev/ttyAMA1╴╫╴╴╴┐  │ │                            ║   │
║ ║*PPS╴╫╴GPIO7╴╫╴╴╴╴╴/dev/pps1╴╴╴╴╫╴┬╴)╴╴)╴)╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╫╴╴╴)╴[+]╴PPS1*
╚═╩═════╝       ╚══════════════════╝ ╵ ╵  │ │ ╔══════════════════╗       ║   │  ╵
                                     ╵ ╵  │ │ ║ GPSD             ║       ║   │  ╵
                                     ╵ ╵  │ │ ║                  ║       ║   │  ╵
                                     ╵ ╵  │ └─╫─GPS0──┬──────────╫─SHM0──╫───)──)──GPS0
                                     ╵ ╵  │   ║       │        ┌─╫─SHM1──╫───┴──)──PSM0
                                     ╵ ╵  └───╫─PPS0─[+]───────┴─╫─SOCK0─╫──────)──PST0
                                     ╵ ╵      ║                  ║       ║      ╵
                                     ╵ └╴╴╴╴╴╴╫╴GPS1╴╴╴╴╴┬╴╴╴╴╴╴╴╫╴SHM2╴╴╫╴╴╴╴╴╴)╴╴GPS1*
                                     ╵        ║          │     ┌╴╫╴SHM3╴╴╫╴╴╴╴╴╴┴╴╴PSM1*
                                     └╴╴╴╴╴╴╴╴╫╴PPS1╴╴╴╴[+]╴╴╴╴┴╴╫╴SOCK1╴╫╴╴╴╴╴╴╴╴╴PST1*
                                              ╚══════════════════╝       ╚══════════════
*) optional second PPS device
```
## requirements

### hardware:
- Raspberry Pi (with LAN)
- SD card
- working network environment (with a connection to internet for installation only)
- GPS module with PPS output (e.g. [Adafruit Ultimate GPS Breakout - 66 channel w/10 Hz updates - Version 3](https://www.adafruit.com/products/746)
- optionally a second PPS device

### software:
- Raspberry Pi OS Bullseye (2021-10-30 or newer, [(link)](https://www.raspberrypi.org/downloads/raspbian/))

## installation:
assuming,
- your Raspberry Pi is running Raspberry Pi OS Bullseye (2021-10-30 or newer),
- and has a proper connection to the internet via LAN.
- and your SD card is expanded,
- and you connected the GPS module direct to the RPi's RX/TX pins of the GPIO and the GPS PPS pin to the RPi' GPIO #4

1. run `bash install-gps-pps.sh` to install necessary packages and setup Kernel PPS, GPSD, and NTP with PPS support.
2. reboot your RPi with `sudo reboot`
3. **_in case you have a RPi3, RPi3+, RPi4 or RPi0w with a built-in Bluetooth adapter, and the script didn't disabled Bluetooth successfully, please run `sudo raspi-conf` and disable the Bluetooth adapter there. otherwise the built-in Bluetooth adapter will block the serial port of the GPIO pins._**

done.

## NOTES:
gpsd v3.20 available on bullseye repository may have an issue with autobaud feature (finding the correct baud rate of the gps device automatically).<br>
you may have to set the correct baud rate explicitly in the file `/etc/default/gpsd`<br>
e.g. for baud rate 115200:<br>
`GPSD_OPTIONS="--listenany --nowait --badtime --passive --speed 115200"`
### note1:
the chrony configuration files are in the `/etc/chrony/statum1` folder.
only files with `*.conf` will be included to the configuration.
all other files in that folder will be ignored.
by renaming the files you easily can enable and disable different configuration files.

### note2:
**PPS** is a high precise pulse, without a time information.<br />
**GPS** (NMEA)  has date/time information, but with mostly lower precision.

to combine **GPS** and **PPS** in chrony, there is a specific requirement, [(link)](https://chrony.tuxfamily.org/faq.html#_using_a_pps_reference_clock)<br />
that GPS data and PPS signal must have a time offset of less than **+/-200ms**<br />
otherwise the PPS signal is seen as false-ticker and will be rejected by chrony.

depending on your GPS device the offset used in my script can be way too off.

to adjust the offset of GPS0 edit the file `/etc/chrony/stratum1/10-refclocks-pps0.conf`

refclock  SHM 0  refid GPS0  precision 1e-1  **offset _0.0_**  ...

to find the actual offset, you can use gnuplot (already installed by the script)
and run the plot script 99-calibrate-offset-gps0.gnuplot
to visualize the actual histogram of the measured offsets.<br />
```
# stop gpsd and chrony, delete all log files, restart chrony and gpsd
# wait few seconds to give time to create a log file,
# and start the histogram.

sudo systemctl stop --now gpsd.{service,socket} && sudo systemctl stop --now chrony && \
sudo rm -r /var/log/chrony/*.log && \
sudo systemctl start --now chrony && sudo systemctl start --now gpsd && \
sleep 10 && \
gnuplot ~/RPi-GPS-PPS-StratumOne/gnuplot/99-calibrate-offset-gps0.gnuplot
```
the histogram will updated every minute. keep it running for at least 30 minutes.
the longer you keep it running the better offset value you can find.
(but not longer than 24h. every 24h a new log will started from zero)

the x-value of the highest spike in the histogram is the offset value for the GPS0 you can 
once you got a good offset, you can use your RPi + GPS offline.

### note3:
- **GPS0** (NMEA), has a mostly a low accuracy.

- **PPS0**, has the highest accuracy.<br />
it is passed throught by the kernel to /dev/pps0.<br />
in chrony there is a specific timing offset requirement to PPS, that may cause the PPS0 to be seen as false-ticker by chrony and may be rejected.<br />
(see note2)

- **PSM0**, is coming from the gpsd service via shared memory and is a combination of PPS0+NMEA, but handled by gpsd service.<br />
it has a similar accuracy than the PPS0 directly.

- **PST0**, is used by gpsd socket to provide PPS0+NMEA information.<br />
it has the same accuracy as PSM0 because they have the same time source.

- **GPS1, PPS1, PSM1, PST1**, same as above, but only for the second GPS/PPS device.

to properly restart chrony, use:<br />
```
sudo systemctl stop --now gpsd.{service,socket} && \
sudo systemctl restart --now chrony && \
sudo systemctl start --now gpsd
```
this will disconnect all connected gpsd-clients.

## enable second PPS:
to enable a second PPS source (/dev/pps1), please uncomment the prepared lines in the following files:

- `/boot/config.txt`<br />
uncomment the line to:<br />
`dtoverlay=pps-gpio,gpiopin=7,capture_clear  # /dev/pps1`

- `/etc/default/gpsd`<br />
uncomment the line to:<br />
`DEVICES="/dev/ttyAMA0 /dev/pps0 /dev/pps1"`

- rename file `/etc/chrony/stratum1/11-refclocks-pps1.conf.disabled` to<br />
`/etc/chrony/stratum1/11-refclocks-pps1.conf`

and reboot the system.

**be warned:** as long the kernel of the RPi uses "soft"-interrupts for the second PPS its accuracy is questionable.<br />
for tests i feeded both gpio-pins with the same signal from the same pps-device (shorted both pins) and noticed a time difference of about 20µs in chrony between /dev/pps0 and /dev/pps1<br />
see [(two gpio pins has different delays?)](https://www.raspberrypi.org/forums/viewtopic.php?f=28&t=277074)
