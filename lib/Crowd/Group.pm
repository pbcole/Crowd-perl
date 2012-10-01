package Crowd::Group;

use strict;
use warnings;
use Crowd::User;
use Data::Dumper;

use Mouse;

has name => ( is => 'ro', isa => 'Str' );
has link => ( is => 'ro', isa => 'Str', lazy_build => 1 );
has crowd => ( is => 'ro', isa => 'Crowd', required => 1 );

sub _build_link {
	my ($self) = @_;

	return $self->baseuri()."/group?groupname=".$self->name();
}

sub members {
	my ($self) = @_;

	# get the list of members of the group
	my $addr = $self->crowd()->baseuri()."/group/user/direct"; 
	my $res = $self->crowd()->_getrequest($addr, {groupname => $self->name()});
	my $returned_data = eval { JSON::Any->new()->jsonToObj($res->content()) };

	print "Group member lookup: ".Dumper($returned_data);

	if ($res && !$@) {
		if ($res->is_success()) {
			return [map {$self->crowd()->lookup_user($_->{name})} @{$returned_data->{users}}];
		}
		else {
		#	$self->clear_curr_user();
			return Crowd::Error->new($returned_data);
		}
	}
	else {
#		$self->clear_curr_user();
		return Crowd::Error->new({reason => "can't get request, eval: $@", message => "Can't get group details"});
	}
}

sub add_member {
}

sub delete_member {
}

sub create_group {
	my ($self) = @_;

	# POST to the link URL to get the group created
}


sub delete_group {
}



no Mouse;

1;

