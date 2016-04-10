package Mojolicious::Plugin::Gossiper;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::IOLoop;
use IO::Socket::INET;

our $VERSION = '0.01';

has listen_port	=> 9998;
has loop	=> sub {Mojo::IOLoop->singleton};
has reactor	=> sub {shift()->loop->reactor};
has udp_sock	=> sub {
	my $self = shift;
	IO::Socket::INET->new(
		Proto     => "udp",    
		LocalPort => $self->listen_port,
	) or die "Cant bind : $@\n";
};

sub register {
	my $self	= shift;
	my $app		= shift;

	$self->reactor->io($self->udp_sock => sub{
		my $reactor	= shift;
		my $writable	= shift;

		return if $writable;

		my $data;
		$data .= $self->udp_sock->read($data, 1024) until $sock->atmark;
		$app->log->debug("DATA: ", $data);
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
