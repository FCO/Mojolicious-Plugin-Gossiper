#!/usr/bin/env perl
use Mojolicious::Lite;

use lib "lib";
plugin "Gossiper" => {nodes => [ split /\s*,\s*/, $ENV{GOSSIPER_PEERS} ]};

app->hook(gossip_data_patch => sub {
	#app->log->debug("got data => @_");
});

app->hook(gossip_data_patch => sub {
	app->log->debug(app->dumper(shift));
});

Mojo::IOLoop->recurring(10 => sub {
	app->log->info("NODES => " . join(", ", app->gossip_nodes));
});

app->start
