package Mojolicious::Plugin::Gossiper;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;
use IO::Socket::INET;
use Mojo::JSON;

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

sub add_to_news {
	my $self	= shift;
	my $data	= shift;

	for my $new (@{ ref $data eq "ARRAY" ? $data : [$data] }) {
		push @{ $self->news }, { %$new, counter => 0 }
	}
	$self->app->plugins->emit_hook(patch_gossip_data => $data)
}

sub register {
	my $self	= shift;
	my $app		= shift;
	my $conf	= shift;

	if(defined $conf and ref $conf eq "HASH") {
		if (exists $conf->{peers}) {
			$self->peers($conf->{peers});
		}
	}

	$self->reactor->io($self->udp_sock => sub{
		my $reactor	= shift;
		my $writable	= shift;

		$app->log->debug("reactor call... writable: $writable");

		my $data;
		while($self->udp_sock->recv(my $tmp, 1024)) {
			$app->log->debug("looping... tmp: $tmp");
			$data .= $tmp;
		}

		eval {
			$data = from_json $data;
		};
		return if $@;

		if(defined $data) {
			$app->log->debug("DATA: $data");
			if($self->is_new($data)) {
				$self->add_to_news($data)
			}
			$app->plugins->emit_hook(patch_gossip_data => $data)
		}
	})->watch($self->udp_sock, 1, 0);

	$self->reactor->recurring($self->interval_time => sub {
		if(@{ $self->peers }) {
			my $peer = $self->peers->[rand @{ $self->peers }];
			my $socket = new IO::Socket::INET (
				PeerAddr	=> $peer,
				Proto		=> "udp"
			) or die "ERROR in Socket Creation : $!\n";

			$socket->send("test")
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
