#!/usr/bin/env perl

print "starting...";

use IO::Socket::INET;

$socket = new IO::Socket::INET (
	PeerAddr   => "server:9998",
	Proto        => "udp"
) or die "ERROR in Socket Creation : $!\n";

my $a = 0;
while(sleep 1) {
	warn "Sending data...";
	$socket->send(sprintf '{"test%d": %d}', ++$a, $a)
}
