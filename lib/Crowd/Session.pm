package Crowd::Session;

use Mouse;
use 5.10.1;

has token => ( is => 'ro', isa => 'Str', );
has crowd => ( is => 'ro', isa => 'Crowd', );

use overload '""' => \&stringify, fallback => 1;

sub stringify {
	my ($self) = @_;
	return $self->token();
}

sub session_uri {
	my ($self) = @_;
	
	return $self->crowd()->baseuri()."/session/";
}

sub get_token {
	my ($self) = @_;
	
	my $res = $self->crowd()->_getrequest($self->session_uri().$self->token(), undef, "");
	say $res->content();
	
}

sub validate_token {
	my ($self) = @_;
	
	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>
<validation-factors>
  <validation-factor>
    <name>remote_address</name>
    <value>127.0.0.1</value>
  </validation-factor>
</validation-factors>
};
	my $res = $self->crowd()->_postrequest($self->session_uri().$self->token(), {}, $xml);
	say $res->content();
	
}

no Mouse;

1;
