# tivùsat-M3U

Generates a m3u playlist for [tivùsat](https://en.wikipedia.org/wiki/Tiv%C3%B9sat) channels by parsing SDT, NIT, PAT and PMT tables.

## Description
[minisatip](https://github.com/catalinii/minisatip) does not provide any support for LCN numbering, this script parses the relevant DVB metadata tables to generate an m3u playlist with tivùsat channels compatible with most of the players. The file is served using minitsatip's http server. A .timer runs the script weekly to update the playlist. sysusers.d and tmpfiles.d files create automatically the relevant user and m3u file with the correct permissions.

## Getting Started

### Dependencies

* A running linux system with systemd
* [TSDuck](https://tsduck.io/) package to read the binary tables
* A running minisatip istance

### Examples

see examples/ directory for:
* Example PAT (Program Association Table)
* Example PMT (Program Mapping Table)
* Example NIT (Network Information Table)
* Example SDT (Service Description Table)
* Example M3U File

### Installing

* Install minisatip from your favourite source
* Clone this repository to local folder:
```
git clone
```
* If your package does not come with a .service file for minitsatip you can copy from the systemd/ folder along with its config:
```
sudo cp systemd/minisatip.service /etc/systemd/system/
sudo cp minisatip.conf /etc/minitsatip.conf
sudo vi /etc/minisatip.conf
```
* Customize the config file and copy it along with the script to /usr/local/
```
vi tivusat-m3u.conf
```
```
sudo cp tivusat-m3u.sh /usr/local/bin/
sudo cp tivusat-m3u.conf /usr/local/etc/
```
* Copy the .service and .timer files to /etc/systemd/system/ and enable the timer
```
sudo cp systemd/tivusat-m3u.service /etc/systed/system/
sudo cp systemd/tivusat-m3u.timer /etc/systed/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tivusat-m3u.timer
```
* Copy sysusers.d and tmpfiles.d files
```
sudo cp tmpfiles.d/tivusat-m3u.conf /etc/tmpfiles.d/
sudo systemd-tmpfile --create
```
```
sudo cp sysusers.d/tivusat-m3u.conf /etc/sysusers.d/
sudo systemd-sysusers
```

### Executing program

* The .timer files run the script weekly, you can run it manually by running:
```
sudo systemctl start tivusat-m3u.service
```
or outside systemd:
```
/usr/local/bin/tivusat-m3u.sh
```
## Help

Check the output of the script for any possible errors:
```
journalctl -u tivusat.m3u
```

## TO-DO

* ~~Move script configuration to separate file~~
* Improve logging
* Improve retry logic
* Rewrite parser in python

## License

This project is licensed under the MIT License - see the LICENSE.md file for details

## Acknowledgments

* [minisatip AUR package](https://aur.archlinux.org/packages/minisatip) for the .service file for minisatip and sysusers.d file
