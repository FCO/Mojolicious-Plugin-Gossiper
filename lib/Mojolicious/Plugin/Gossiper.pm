package Mojolicious::Plugin::Gossiper;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;
use IO::Socket::INET;
use Mojo::JSON qw/to_json from_json/;

our $VERSION = '0.01';

has news		=> sub {[]};
has peers		=> sub {[]};
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

sub is_new {
	my $self	= shift;
	my $news	= shift;

	1
}

sub has_news {1}

sub send_news {
	my $self	= shift;
	my $peer	= shift;
	if($self->has_news) {
		my $socket = new IO::Socket::INET (
			PeerAddr	=> $peer,
			Proto		=> "udp"
		) or die "ERROR in Socket Creation : $!\n";

		$socket->send(to_json($self->news))
	}
}

sub register {
	my $self	= shift;
	my $app		= shift;
	my $conf	= shift;

	$app->helper(add_to_gossip_news => sub{
		my $c		= shift;
		my $data	= shift;

		for my $new (@{ ref $data eq "ARRAY" ? $data : [$data] }) {
			push @{ $self->news }, { %$new, counter => 0 }
		}
		$app->plugins->emit_hook(updated_gossip_data => $data)
	});

	if(defined $conf and ref $conf eq "HASH") {
		if (exists $conf->{peers}) {
			$self->peers($conf->{peers});
			$app->add_to_gossip_news({add => $self->peers});
		}
	}

	$self->reactor->io($self->udp_sock => sub{
		my $reactor	= shift;
		my $writable	= shift;

		$app->log->debug("reactor call... writable: $writable");

		my $data;
		while($self->udp_sock->recv(my $tmp, 1024)) {
			$data .= $tmp;
		}

		eval {
			$data = from_json $data;
		};
		return if $@;

		$app->log->debug("received: ", $app->dumper($data));

		if(defined $data) {
			$app->log->debug("DATA: $data");
			if($self->is_new($data)) {
				$app->add_to_gossip_news($data)
			}
			$app->plugins->emit_hook(gossip_data_patch => $data)
		}
	})->watch($self->udp_sock, 1, 0);

	$self->reactor->recurring($self->interval_time => sub {
		if(@{ $self->peers }) {
			#$app->log->debug("has peers");
			my $peer = $self->peers->[rand @{ $self->peers }];
			#$app->log->debug("choose: $peer");
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
