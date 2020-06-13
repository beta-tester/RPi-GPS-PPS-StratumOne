# RPi-GPS-PPS-StratumOne

setup a Raspberry Pi as an Stratum One NTP server.<br />
it is a private project i have made for myself.<br />
i did not keeped an eye on network security.

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
║ ╔═════╣       ║  │               ║                                    ╔══════════════
║ ║NMEA─╫──TX───╫─[+]─/dev/ttyAMA0─╫─────┬───NMEA──x                    ║ CHRONY
║ ╠═════╣       ║                  ║     │                              ║
║ ║ PPS─╫─GPIO4─╫─────/dev/pps0────╫───┬─)──────────────────────────────╫──[+]────PPS0
╚═╩═════╝       ║                  ║   │ │                              ║   │
  ╠═════╣       ║                  ║   │ │                              ║   │
║ ║ PPS╴╫╴GPIO7╴╫╴╴╴╴╴/dev/pps1╴╴╴╴╫╴┬╴)╴)╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╴╫╴╴╴)╴[+]╴PPS1*
╚═╩═════╝       ╚══════════════════╝ ╵ │ │ ╔════════════════════╗       ║   │  ╵
                                     ╵ │ │ ║ GPSD               ║       ║   │  ╵
                                     ╵ │ │ ╠═════════════╗      ║       ║   │  ╵
                                     ╵ │ └─╫─NMEA──┬──┬──╫──────╫─SHM0──╫───┴──┴──GPSD
                                     ╵ │   ║       │  |  ║    ┌─╫─SHM1──╫─────────PSM0
                                     ╵ └───╫─PPS0─[+]─)──╫──┬─┴─╫─SOCK0─╫─────────PST0
                                     ╵     ║          |  ║ [+]──╫─SHM2──╫─────────PSMD
                                     ╵     ║          |  ║  | ┌╴╫╴SHM3╴╴╫╴╴╴╴╴╴╴╴╴PSM1*
                                     └╴╴╴╴╴╫╴PPS1╴╴╴╴[+]╴╫╴╴┴╴┴╴╫╴SOCK1╴╫╴╴╴╴╴╴╴╴╴PST1*
                                           ╚═════════════╩══════╝       ╚══════════════
*) optional second PPS device
```
## requirements

### hardware:
- Raspberry Pi (with LAN)
- SD card
- working network environment (with a connection to internet for installation only)
- GPS module with PPS output (Adafruit Ultimate GPS Breakout - 66 channel w/10 Hz updates - Version 3; https://www.adafruit.com/products/746)
- optionally a second PPS device

### software:
- Raspberry Pi OS Buster (2020-05-27 or newer, https://www.raspberrypi.org/downloads/raspbian/)

## installation:
assuming,
- your Raspberry Pi is running Raspberry Pi OS Buster (2020-05-27 or newer),
- and has a proper connection to the internet via LAN.
- and your SD card is expanded,
- and you connected the GPS module direct to the RPi's RX/TX pins of the GPIO and the GPS PPS pin to the RPi' GPIO #4

1. run `bash install-gps-pps.sh` to install necessary packages and setup Kernel PPS, GPSD, and NTP with PPS support.
2. reboot your RPi with `sudo reboot`
3. **_in case you have a RPi3, RPi3+, RPi4 or RPi0w with a built-in bluetooth adapter, and the script didn't disabled blutooth sucesssfully, please run `sudo raspi-conf` and disable the bluetooth adapter there. otherwise the built-in bluetooth adapter will block the serial port of the GPIO pins._**

done.

## NOTES:
### note1:
**PPS** is a high precise pulse, without a time information.<br />
**GPSD** (**NMEA**)  has date/time information, but with very low precision.

to combine **NMEA** and **PPS** in chrony, there is a specific requirement,<br />
that NMEA data and PPS signal must have a time offset less than **+/-200ms**.<br />
otherwise the PPS signal is seen as falsetick and will be rejected by chrony.

depending on your GPS device the offset used in my script can be way too off.

to adjust the offset of GPSD edit the file `/etc/chrony/stratum1/10-refclocks.conf`

refclock  SHM 0  refid GPSD  precision 1e-1  **offset _0.475_**  ...

to find the actual offset, you can use gnuplot (already installed by the script)
and run the plot script 99-calibrate-offset-gpsd.gnuplot
to visualise the actual histogramm of the measured offsets.<br />
```
# stop gpsd and chony, delete all log files, restart chrony and gpsd
# wait few seconds to give time to create a log file,
# and start the histogram.

sudo systemctl stop gpsd.* && sudo systemctl stop chrony && \
sudo rm -r /var/log/chrony/*.log && \
sudo systemctl start chrony && sudo systemctl start gpsd && \
sleep 10 && \
gnuplot ~/RPi-GPS-PPS-StratumOne/gnuplot/99-calibrate-offset-gpsd.gnuplot
```
the histogram will updated every minute. keep it running for at least 30 minutes.
the longer you keep it running the better offset value you can find.
(but not longer than 24h. every 24h a new log will started from zero)

the x-value of the highest spike in the histogram is the offset value for the GPSD you can 
once you got a good offset, you can use your RPi + GPS offline.

### note2:
- **GPSD** (NMEA), has a low accuracy of about +/-200ms.
<br />

- **PPS0**, has the highest accuracy.<br />
it is passed throught by the kernel to /dev/pps0.<br />
in chrony there is a specific timing offset requirement to GPSD, that may cause the PPS0 to be seen as falsetick by chrony and may be rejected.

- **PSM0**, is coming from the gpsd service via shared memory and is also a combination of PPS0+NMEA, but handled by gpsd service.<br />
it has a similar accuracy than the PPS0 direckly.<br />
gpsd is "_simulating_" PPS internaly, in the case there is no valid PPS signal received on time from the gps device.<br />
because of that chrony will not reject the PSM0 source in this case.<br />
for this reason use PSM1 or PST0 instead of PPS0, in case you have a weak intermitten PPS signal coming from the gps device.

- **PST0**, is used by gpsd socket to provide PPS0+NMEA information.<br />
it has the same accuracy as PSM0 because they have the same time source.
<br />


- **PSMD**, is coming from the gpsd service via shared memory and is also a combination of PPS0+NMEA+(PPS1), but handled by gpsd service.<br />
it has a similar accuracy than the PPS0 + PPS1 direckly.
<br />


- **PPS1**, has the highest accuracy.<br />
it is passed throught by the kernel to /dev/pps1.<br />
in chrony there is a specific timing offset requirement to GPSD, that may cause the PPS1 to be seen as falsetick by chrony and may be rejected.

- **PSM1**, is coming from the gpsd service via shared memory and is also a combination of PPS1+NMEA, but handled by gpsd service.<br />
it has a similar accuracy than the PPS1 direckly.<br />

- **PST1**, is used by gpsd socket to provide PPS1+NMEA information.<br />
it has the same accuracy as PSM1 because they have the same time source.

to properly restart chrony, use:<br />
`sudo systemctl stop gpsd.* && sudo systemctl restart chrony && sudo systemctl start gpsd`<br />
this will disconnect all connected gpsd-clients.
