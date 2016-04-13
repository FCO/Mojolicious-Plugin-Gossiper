#!/usr/bin/env perl
use Mojolicious::Lite;

use lib "lib";
plugin "Gossiper" => {nodes => [ split /\s*,\s*/, $ENV{GOSSIPER_PEERS} ]};

app->hook(gossip_data_patch => sub {
	#app->log->debug("got data => @_");
});

app->hook(updated_gossip_data => sub {
	my $nodes = shift;
	app->log->debug("nodes => @$nodes");
});

app->start
