package Mojolicious::Plugin::Gossiper;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;
use IO::Socket::INET;
use Mojo::JSON qw/to_json from_json/;
use Time::HiRes qw/time/;
use Mojo::Util qw/sha1_sum/;

our $VERSION = '0.01';

has news		=> sub {[]};
has news_cache		=> sub {{}};
has nodes		=> sub {{}};
has listen_port		=> 9998;
has interval_time	=> .1;
has loop		=> sub {Mojo::IOLoop->singleton};
has reactor		=> sub {shift()->loop->reactor};
has udp_sock		=> sub {
	my $self = shift;
	IO::Socket::INET->new(
		Proto		=> "udp",    
		LocalPort	=> $self->listen_port,
		Blocking	=> 0,
	) or die "Cant bind : $@\n";
};

sub get_local_ip_address {
	my $node = shift;
	my $socket = IO::Socket::INET->new(
		Proto       => 'udp',
		PeerAddr    => $node,
	);

	# A side-effect of making a socket connection is that our IP address
	# is available from the 'sockhost' method
	my $local_ip_address = $socket->sockhost;

	return $local_ip_address;
}

sub is_new {
	my $self	= shift;
	my $news	= shift;

	1
}

sub has_news {
	my $self = shift;
	for my $index(0 .. $#{ $self->news }) {
		my $new = $self->news->[$index];
		$new->{counter}++;
		 splice @{ $self->news }, $index, 1 if $new->{counter} >= keys(%{ $self->nodes }) * 2;
	}
	+@{ $self->news }
}

sub send_news {
	my $self	= shift;
	my $peer	= shift;
	if($self->has_news) {
		my $socket = new IO::Socket::INET (
			PeerAddr	=> $peer,
			Proto		=> "udp"
		) or die "ERROR in Socket Creation : $!\n";

		$socket->send(to_json([ map {{obj => $_->{obj}, sha => $_->{sha}}} @{ $self->news } ]));
	}
}

sub register {
	my $self	= shift;
	my $app		= shift;
	my $conf	= shift;

	$app->helper(gossip_nodes => sub{
		keys %{ $self->nodes }
	});

	$app->helper(add_to_gossip_news => sub{
		my $c		= shift;
		my $data	= shift;

		my @patch;
		for my $obj (@{ ref $data eq "ARRAY" ? $data : [$data] }) {
			my $new = {};
			if(ref $obj eq "HASH" and exists $obj->{obj}) {
				$new = $obj;
				$obj = $new->{obj}
			} else {
				$new->{obj} = $obj
			}
			$new->{added}	= time;
			$new->{counter}	= 0;
			if(not exists $new->{sha}) {
				$new->{sha} = sha1_sum(to_json($new))
			} else {
				next if exists $self->news_cache->{$new->{sha}}
			}
			push @patch, $obj;
			$self->news_cache->{$new->{sha}} = $new;
			push @{ $self->news }, $new
		}
		my %nodes = %{ $self->nodes };
		for my $patch(@patch) {
			for my $cmd(keys %$patch) {
				#$app->log->debug($app->dumper($patch));
				if($cmd eq "add") {
					$nodes{$_} = 1 for @{ $patch->{$cmd} };
				} elsif($cmd eq "del") {
					delete $nodes{$_} for @{ $patch->{$cmd} };
				}
			}
		}
		$self->nodes(\%nodes);
		$app->plugins->emit_hook(updated_gossip_data => $self->nodes)
	});

	#$app->add_to_gossip_news({add => [$app->gossip_node]});

	if(defined $conf and ref $conf eq "HASH") {
		if (exists $conf->{nodes}) {
			$self->nodes({ map {($_ => 1)} @{ ref $conf->{nodes} eq "ARRAY" ? $conf->{nodes} : [$conf->{nodes}] }});
			$app->add_to_gossip_news({add => [keys %{ $self->nodes }]});
		}
		$app->add_to_gossip_news({add => [get_local_ip_address((keys %{ $self->nodes })[0]) . ":9998"]}) if keys %{ $self->nodes };
	}

	$self->reactor->io($self->udp_sock => sub{
		my $reactor	= shift;
		my $writable	= shift;

		#$app->log->debug("reactor call... writable: $writable");

		my $data;
		my $client;
		while(my $tmp_client = $self->udp_sock->recv(my $tmp, 1024)) {
			$data .= $tmp;
			$client = $tmp_client;
		}

		eval {
			$data = from_json $data;
		};
		return if $@;

		if(defined $data) {
			if($self->is_new($data)) {
				$app->add_to_gossip_news($data)
			}
			$app->plugins->emit_hook(gossip_data_patch => $data)
		}
	})->watch($self->udp_sock, 1, 0);

	$self->reactor->recurring($self->interval_time => sub {
		if(my @nodes = keys %{ $self->nodes }) {
			#$app->log->debug("has nodes");
			my $peer = $nodes[rand @nodes];
			$self->send_news($peer)
		}
	});
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Gossiper - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('Gossiper');

  # Mojolicious::Lite
  plugin 'Gossiper';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Gossiper> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::Gossiper> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
