package Crowd::Error;

use Mouse;

has reason => ( isa => 'Str', is => 'ro' );
has message => ( isa => 'Str', is => 'ro' );

no Mouse;

1;
