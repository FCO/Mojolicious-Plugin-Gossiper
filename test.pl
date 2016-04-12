#!/usr/bin/env perl
use Mojolicious::Lite;

use lib "lib";
plugin "Gossiper" => {peers => [ split /\s*,\s*/, $ENV{GOSSIPER_PEERS} ]};

app->hook(gossip_data_patch => sub {
	app->log->debug("got data => @_");
});

app->start
