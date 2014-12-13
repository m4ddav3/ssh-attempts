#!/bin/env perl
use strict; use warnings;

use Data::Dumper qw(Dumper);
use JSON qw();

use Geo::IP qw(GEOIP_CITY_EDITION_REV1 GEOIP_STANDARD);

use Net::TcpDumpLog;
use NetPacket;

use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::TCP;

# Whitelist loopback and local network subnets
my $whitelist = [
    '127.0.0.0/8',
    '192.168.0.0/16',
];

my $json = JSON->new()->utf8(1)->pretty(1);
my $geo  = Geo::IP->open('/etc/alternatives/GeoIPCity.dat');
#my $geo  = Geo::IP->open_type(GEOIP_CITY_EDITION_REV1);


my $logfile = shift || die "Requires a pcap file parameter";
die "File not found" unless (-e $logfile);

my $log = Net::TcpDumpLog->new(); 
$log->read( $logfile );

my $geojson = {};

sub add_feature {
    my ($ip, $port, $lat, $lon) = @_;

    my $feature = {
        type => 'Feature',
        geometry => {
                type => 'Point',
                coordinates => [ $lon, $lat ],
        },
        properties => {
            'IP Address' => $ip,
        },
    };

    push @{$geojson->{$port}}, $feature;
}

foreach my $index ($log->indexes) { 
    my ($length_orig, $length_incl, $drops, $secs, $msecs)
        = $log->header($index);

    next if ($secs < 1417392000);

    #print Dumper [$length_orig, $length_incl, $drops, $secs, $msecs];

    my $data = $log->data($index);

    my $ip_obj = NetPacket::IP->decode($data);
    next unless $ip_obj->{proto} == NetPacket::IP::IP_PROTO_TCP;
    next if ($ip_obj->{src_ip} =~ m/(192\.168\.1\.\d{1,3}|127\.0\.0\.1)/);

    #print Dumper $ip_obj;

    my $tcp_obj = NetPacket::TCP->decode($ip_obj->{data});
    #print Dumper $tcp_obj;
    #last;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($secs + $msecs/1000);

    $year += 1900;
    $mon  += 1;

    my $timestamp = sprintf(
        "%04d-%02d-%02d %02d:%02d:%02d.%d", 
        $year, $mon, $mday, $hour, $min, $sec, $msecs,
    );

    #my $country = $geo->country_code_by_addr($ip_obj->{src_ip}) || '';
    my $record = $geo->record_by_addr($ip_obj->{src_ip});

    my ($country, $city, $lat, $lon);

    if (defined $record) {
        $country = $record->country_code3;
        $city    = $record->city;
        $lat     = $record->latitude;
        $lon     = $record->longitude;
    }

    print sprintf("%s,%s:%s,%s:%s,%s,%s,%s,%s\n",
        $timestamp,
        $ip_obj->{src_ip},
        $tcp_obj->{src_port},
        $ip_obj->{dest_ip},
        $tcp_obj->{dest_port},
        $country||'',
        $city||'',
        $lat//'',
        $lon//'',
    );
    #last;
    
    add_feature($ip_obj->{src_ip}, $tcp_obj->{dest_port}, 0+$lat, 0+$lon) if ($lat && $lon);
}

sub write_geojson {
    my ($port, $name) = @_;

    my $filename = sprintf("%s-attempts.geojson", $name);

    my $jsondata = {
        type => 'FeatureCollection',
        features => $geojson->{$port},
    };

    open (my $jsonfile, '>', $filename) or die $!;
    print $jsonfile $json->encode($jsondata);
    close $jsonfile;
}

#open (my $jsonfile, '>', 'ssh-attempts.geojson') or die $!;
#print $jsonfile $json->encode($geojson->{22});
#close $jsonfile;

my $portmap = {
    22 => 'ssh',
    80 => 'http',
    443 => 'https',
    53 => 'dns',
};

foreach my $port (keys %$geojson) {
    write_geojson($port, $portmap->{$port}//$port);
}

#write_geojson(22, 'ssh')    if (scalar(@{$geojson->{22}}));
#write_geojson(80, 'http')   if (scalar(@{$geojson->{80}}));
#write_geojson(443, 'https') if (scalar(@{$geojson->{443}}));
