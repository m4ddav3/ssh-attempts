ssh-attempts
============

Display SSH attempts on my RPi by geographical region

## Requirements
- iptables
- ulog
- Perl >= 5.14 (could support something lower, haven't tested this)
 - Geo::IP
 - NetPacket
 - Net::TcpDumpLog
 - JSON

-GeoIP City Edition DB (normally installed as GeoIpCity.dat)

## Setup
I use the following command to add a rule to `iptables`:

`iptables -I INPUT 3 -p tcp --dport 22 -j ULOG --ulog-nlgroup 1 --ulog-cprange 4096`

This tells iptables to log all SSH communication to ULOG. On my Pi, this adds entries to `/var/log/ulog/pcap.log`

The script which processes the pcap file will be released shortly.

Still some work to do:
- [ ] Get the lat/lon coords right
- [ ] Add the script and instructions which drive the data
- [ ] Expand to account for other access attemps (HTTP/S, etc)
