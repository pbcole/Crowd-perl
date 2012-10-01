package Crowd::Message;

use Mouse;
use 5.10.1;
has message => ( is => 'ro', isa => 'Str', required => 1);

use overload '""' => \&stringify, fallback => 1;

sub stringify {
	my ($self) = @_;
	return $self->message();
}

no Mouse;

1;