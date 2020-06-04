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
╔══════╗    ╔═══════════════╗                      ╔═══════
║ GPS  ╫─RX─╫─┐ KERNEL      ║                      ║CHRONY
║ ╔════╣    ║ │             ║                      ║
║ ║NMEA╫─TX─╫─┴─/dev/serial0╫───┬──────────────────╫─NMEA──
║ ╠════╣    ║               ║   │                  ║ (+)
║ ║ PPS╫GPIO╫───/dev/pps0───╫─┬─)──────────────────╫─PPS───
╚═╩════╝    ╚═══════════════╝ │ │ ╔══════════╗     ║
                              │ │ ║ GPSD     ║     ║
                              │ │ ╠══════╗   ║     ║
                              │ └─╫NMEA┐ ║ ┌─╫SHM2─╫─PPSx──
                              │   ║(+) ├─╫─┤ ║     ║
                              └───╫PPS─┘ ║ └─╫SOCK─╫─PPSy──
                                  ╚══════╩═══╝     ╚═══════
```
## requirements

### hardware:
- Raspberry Pi (with LAN)
- SD card
- working network environment (with a connection to internet for installation only)
- GPS module with PPS output (Adafruit Ultimate GPS Breakout - 66 channel w/10 Hz updates - Version 3; https://www.adafruit.com/products/746)

### software:
- Raspberry Pi OS Buster Lite (2020-02-13 or newer, https://www.raspberrypi.org/downloads/raspbian/)

## installation:
assuming,
- your Raspberry Pi is running Raspberry Pi OS Buster Lite (2020-02-13 or newer),
- and has a proper connection to the internet via LAN.
- and your SD card is expanded,
- and you connected the GPS module direct to the RPi's RX/TX pins of the GPIO and the GPS PPS pin to the RPi' GPIO #4

1. run `bash install-gps-pps.sh` to install necessary packages and setup Kernel PPS, GPSD, and NTP with PPS support.
2. reboot your RPi with `sudo reboot`
3. **_in case you have a RPi3, RPi3+, RPi4 or RPi0w with a built-in bluetooth adapter, please run `sudo raspi-conf` and disable the bluetooth adapter there. otherwise the built-in bluetooth adapter will block the serial port of the GPIO pins._**

done.

## NOTE:
to combine NMEA and PPS in chrony, there is a specific requirement,<br />
that NMEA data and PPS signal must have a time offset less than +/-200ms.<br />
otherwise the PPS signal is seen as falsetick and will be rejected by chrony.

depending on your GPS device the offset used in my script can be way too off.

to adjust the offset of NMEA edit the file /etc/chrony/chrony.conf<br />
refclock  SHM 0  refid NMEA  precision 1e-1  **offset _0.475_**  ...

to find the actual offset, enable some NTP servers to use in the chrony.conf file<br />
and connect your RPi + GPS to the internet.
keep the RPi + GPS + internet running for at least 30 minutes<br />
after the GPS device finished its cold-/warm-start and got a proper GPS signal.

on the console, type in `watch -n 1 chronyc -m sources`:<br />
for example:
```
MS Name/IP address         Stratum Poll Reach LastRx Last sample               
===============================================================================
#? NMEA                          0   2   377     5   +480ms[ +480ms] +/-  200ms
#? PPS                           0   2     0     0     +0ns[+2000ms] +/- 2000ms
...
^- ptbtime1.ptb.de               1   4   377    79  -4924us[-4924us] +/-   13ms
...
```
be sure you see on NMEA and your selected ntp server the value of 377 in the column "reach".

`NMEA 0 2 377 5 +480ms ...`<br />
in this example the current offset of NMEA is +480ms.<br />
this would be too high to get a proper lock of PPS to NMEA in chrony.

as soon the offset is pernamently less than +/-200ms,<br />
you should see that PPS is starting to be marked as reached by chrony.<br />
377  means (11111111b), at the last 8 poll intervals a proper time signal was reached.
```
MS Name/IP address         Stratum Poll Reach LastRx Last sample               
===============================================================================
#? NMEA                          0   2   377     5    +16ms[  +16ms] +/-  200ms
#? PPS                           0   2   377     4   +128ns[ +142ns] +/- 1111ns
```

once you got a good offset, you can use your RPi + GPS offline.
