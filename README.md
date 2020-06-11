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
       ╚══════╝   ┌──╢ h ╟──┐    ║      ║
                  │  ╚═══╝  │    ╚══════╝
               ╔══╧══╗   ╔══╧══╗
               ║ PC1 ║   ║ PC2 ║
               ╚═════╝   ╚═════╝
```
### overview: path of time source
(without external NTP servers)
```
╔═══════╗      ╔══════════════════╗
║ GPS   ╫──RX──╫──┐ KERNEL        ║
║ ╔═════╣      ║  │               ║                             ╔════════════
║ ║NMEA─╫──TX──╫─[+]─/dev/serial0─╫───┬───NMEA──x               ║ CHRONY
║ ╠═════╣      ║                  ║   │                         ║
║ ║ PPS─╫─GPIO─╫─────/dev/pps0────╫─┬─)─────────────────────────╫──[+]─PPS0─
╚═╩═════╝      ╚══════════════════╝ │ │ ╔═══════════════╗       ║   │
                                    │ │ ║ GPSD      ┌───╫─SHM0──╫───┴──NMEA─
                                    │ │ ╠═════════╗ │   ║       ║
                                    │ └─╫─NMEA─┬──╫─┘ ┌─╫─SHM1──╫──────PPSx─
                                    │   ║      │  ║   ├─╫─SHM2──╫──────PPSy─
                                    └───╫─PPS─[+]─╫───┴─╫─SOCK──╫──────PPSz─
                                        ╚═════════╩═════╝       ╚════════════
```
## requirements

### hardware:
- Raspberry Pi (with LAN)
- SD card
- working network environment (with a connection to internet for installation only)
- GPS module with PPS output (Adafruit Ultimate GPS Breakout - 66 channel w/10 Hz updates - Version 3; https://www.adafruit.com/products/746)

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
**NMEA** has date/time information, but with very low precision.

to combine **NMEA** and **PPS** in chrony, there is a specific requirement,<br />
that NMEA data and PPS signal must have a time offset less than **+/-200ms**.<br />
otherwise the PPS signal is seen as falsetick and will be rejected by chrony.

depending on your GPS device the offset used in my script can be way too off.

to adjust the offset of NMEA edit the file `/etc/chrony/stratum1/10-refclocks.conf`

refclock  SHM 0  refid NMEA  precision 1e-1  **offset _0.475_**  ...

to find the actual offset, you can use gnuplot (already installed by the script)
and run the plot script 99-calibrate-offset-nmea.gnuplot
to visualise the actual histogramm of the measured offsets.<br />
```
# stop gpsd, stop chony, delete all log files, restart chrons and gpsd
# wait one minute to give time to create a log file,
# and start the histogram.

sudo systemctl stop gpsd.* && sudo systemctl stop chrony && \
sudo rm -r /var/log/chrony/*.log && \
sudo systemctl start chrony && sudo systemctl start gpsd && \
sleep 60 && \
gnuplot ~/RPi-GPS-PPS-StratumOne/gnuplot/99-calibrate-offset-nmea.gnuplot
```
the histogram will updated every minute. keep it running for at least 30 minutes.
the monger you keep it running the better offset value you can find.

the x-value onf the highest spike in the histogramm is the offset value for the NMEA you can 
once you got a good offset, you can use your RPi + GPS offline.

### note2:
- **NMEA**, has an accuracy of about +/-200ms.<br />
it is available mostely as soon the GPS finished its cold- or warm- start<br />or immediately, when the device has an internal RTC with backup battery.
- **PPS0**, has the highest accuracy.<br />
it is passed by the kernel to /dev/pps0.<br />
in chrony there is a specific timing offset requirement to NMEA, that may cause the PPS to be seen as falsetick and may be rejected by chrony.
- **PPSx**, is coming from the gpsd service via shared memory and is also a combination of NMEA and PPS, but handled by gpsd service.<br />
it has a similar accuracy than the PPS direckly.<br />
gpsd is "_simulating_" PPS internaly, in the case there is no real PPS received on time.
even there is no real PPS signal coming from the gps device on time, chrony will see the PPSx as trusted time reference.<br />
for this reason use PPSx, PPSy or PPSz, in case you have a weak intermitten PPS signal coming from the gps device.
- **PPSy**, is coming also from gpsd service like as PPSx.<br />
it has the same accuracy as PPSx because they have the same time source.<br />
- **PPSz**, is coming also from gpsd service like as PPSx but via a socket.<br />
it has the same accuracy as PPSx because they have the same time source.

to properly restart chrony, use:<br />
`sudo systemctl stop gpsd.* && sudo systemctl restart chrony && sudo systemctl start gpsd`<br />
but this will disconnect all connected gpsd-clients.
