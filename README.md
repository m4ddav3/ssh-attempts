ssh-attempts
============

Display SSH attempts on my RPi by geographical region. It uses iptables and ulog to capture the connections, and Maxmind's freely available Geo IP database to lookup city locations.

These instructions relate to my specific setup, which is almost guaranteed to be different to yours. Modfiy as appropriate!

## Requirements
Most of these are available via your favourite package manager

- iptables
- ulog (with pcap plugin)
- Perl >= 5.14 (could support something lower, haven't tested this)
 - Geo::IP
 - NetPacket
 - Net::TcpDumpLog
 - JSON
- GeoIP City Edition DB (normally installed as GeoIpCity.dat)
 - I used `geoip-database-contrib` from Debian

## Setup

#### `ulogd`

Check that the pcap module is being used by ulogd, by looking at `/etc/ulogd.conf`. You may need to add or uncomment the following line:
`plugin="/usr/lib/ulogd/ulogd_PCAP.so"`

The `[PCAP]` section will tell you where the log file is going to be written. Take a note of this

Restart ulogd
`sudo /etc/init.d/ulogd restart`

#### `iptables`

I use the following command to add a rule to my existing `iptables` config:

`iptables -I INPUT 3 -p tcp --dport 22 -j ULOG --ulog-nlgroup 1 --ulog-cprange 4096`

This tells iptables to log all SSH communication to ULOG. On my RPi, this adds entries to `/var/log/ulog/pcap.log`.
The rule is at position 3 on my RPi, because rules 1 and 2 short circuit established/related traffic, and traffic from my local subnet.

The script which processes the pcap file will be released shortly.

## Usage
Once your machine has had a number of attempts on it, the log file should have some nice data in it. Now to parse it into some geojson files:

`time perl parse-iptables-ulog.pl /var/log/ulog/pcap.log > parsed_iptables.csv`

You may have to use a different location for the logfile depending on your setup, refer to the file location that you noted from the ulogd step.
The output of the script is csv delimited lines for each log entry. I redirect this to a file to record/use another time.

## Todo
- [X] Get the lat/lon coords right
- [X] Add the script and instructions which drive the data
- [X] Expand to account for other access attemps (HTTP/S, etc)
- [ ] Config file
- [ ] CLI options

## References

http://www.stearns.org/doc/iptables-ulog.v0.1.html
