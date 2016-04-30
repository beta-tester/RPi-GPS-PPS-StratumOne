# RPi-GPS-PPS-StratumOne

setup a Raspberry Pi as an Stratum One NTP server.
it is a private project i have made for myself.
i did not keeped an eye on network security.

USE IT AT YOU OWN RISK

#requirements

##hardware:
- Raspberry Pi (with LAN)
- SD card
- working network environment with a connection to internet
- GPS module with PPS output (Adafruit Ultimate GPS Breakout - 66 channel w/10 Hz updates - Version 3; https://www.adafruit.com/products/746)

##software:
- Raspbian Jessie Lite (2016-03-18, https://www.raspberrypi.org/downloads/raspbian/)

## installation:
assuming, your Raspberry Pi is running Raspbian Jessie Lite (2016-03-18),
and has a proper connection to the internet via LAN.
and your SD card is expanded,
and you connected the GPS module direct to the RPi's RX/TX pins of the GPIO and the GPS PPS pin to the RPi' GPIO #4

1. run `bash install-gps-pps.sh` to install necessary packages ans setup Kernel PPS, GPSD, and NTP with PPS support.
2. reboot your RPi with `sudo reboot`

done.
