CHIP Auto-Shutdown
============================

This script will monitor battery voltage and when it drops below a specified threshold it will shutdown CHIP.
It can be installed as a service so frequent battery polling is possible.
Charging state changes are logged to syslog.

# Installation
If you already have git installed, skip this one (obviously).
  ```
  sudo apt-get install git
  ```
Clone this repository (or you could just download the files):
  ```
  git clone https://github.com/noimjosh/chip_autoshutdown.git
  ```
Install the script:
  ```
  cd chip_autoshutdown
  sudo cp ./chip_autoshutdown.sh /usr/bin/
  ```
Install systemd service (so it runs at boot):
  ```
  sudo cp ./chip_autoshutdown.service /lib/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable chip_autoshutdown.service
  ```
Start it:
  ```
  sudo systemctl start chip_autoshutdown.service
  ```
  
#Thanks to
xtacocorex: https://github.com/xtacocorex/chip_batt_autoshutdown/
noimjosh https://github.com/noimjosh/chip_autoshutdown/
CapnBry: https://bbs.nextthing.co/t/updated-battery-sh-dumps-limits-input-statuses/2921
