package Crowd::User;

use Mouse;
use Data::Dumper;

use 5.10.1;

use Module::Find;
my @modules = useall Crowd;

has name => ( isa => 'Str', is => 'ro', required => 1, );
has "last-name" => ( isa => 'Str', is => 'rw', );
has "display-name" => ( isa => 'Str', is => 'rw', );
has email => ( isa => 'Str', is => 'rw', );
has "first-name" => ( isa => 'Str', is => 'rw', );

has crowd => (is => 'ro', isa => 'Crowd', required => 1, );

has user_password_uri => (is => 'ro', isa => 'Str', lazy_build => 1, );

has authenticated => (is => 'rw', isa => 'Bool', default => 0, );

sub _build_user_password_uri {
	my $self = shift;
	return $self->crowd()->baseuri()."/user/password";
}

sub authenticate {
	my ($self, $password) = @_;
	
	my $crowd = $self->crowd();
	
	if (my $authenticated = $crowd->authenticate($self->name(), $password)) {
		$self->authenticated(1);
		$self->$_($authenticated->$_()) foreach ('last-name', 'display-name', 'first-name', 'email');

	}
	return $self->authenticated();
}

sub groups {
	my ($self, $nested) = @_;
	
	my $ua = $self->crowd()->userAgent();
	
	my $addr = $self->crowd()->user_group_uri($nested);
	my $res = $self->crowd()->_getrequest($addr, {username => $self->name()}, "");
	
	# decode the JSON block returned
	my $returned_data = JSON::Any->new()->jsonToObj($res->content());

	return [ map { Crowd::Group->new(name => $_->{name}, crowd => $self->crowd() )} 
	               @{$returned_data->{groups}}];
}

sub is_memberof {
	my ($self, $groupname, $nested) = @_;
	
	my $addr = $self->crowd->user_group_uri($nested);
	my $res = $self->crowd()->_getrequest($addr, {username => $self->name(), groupname => $groupname}, "");
	
	return $res->code() == 200;
}

sub lastname {
	my $sub = 'last-name';
	return shift->$sub(@_);
}

sub displayname {
	my $sub = 'display-name';
	return shift->$sub(@_);
}

sub firstname {
	my $sub = 'first-name';
	return shift->$sub(@_);
}

sub change_password {
	my ($self, $newpassword) = @_;
	
	# take a password and update the record for the current username
	my $addr = $self->user_password_uri();
	my $res = $self->crowd()->_putrequest($addr, {username => $self->name(), }, { password => {value => $newpassword} });
	
	if ($res->code() != 204) {
		return Crowd::Error->new(reason => "Unable to update the user's password", message => $res->content());
	}
	else {
		return $self;
	}
}

sub delete_group_membership {
	my ($self, $groupname) = @_;
	
	my $res = $self->crowd()->_deleterequest($self->crowd()->user_group_uri(), {username => $self->name(), groupname => $groupname});

	given($res->code()) {
		when(204) {
			return Crowd::Message->new(message => "User deleted from group");
		};
		when(403 or 404) {
			my $decoded = eval { JSON::Any->new()->jsonToObj($res->content()) };
			return Crowd::Error->new($decoded // {reason => "problem removing group membership", message => "Invalid response: $@"});
		};
		default {
			return Crowd::Message->new(message => "not sure what happened there...");
		};
	}
	
}

sub add_group_membership {
	my ($self, $groupname) = @_;
	
	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?><group name="$groupname"/>};
	my $res = $self->crowd()->_postrequest( $self->crowd()->user_group_uri(),
                                                {username => $self->name()}, 
                                                $xml
	                                      );
	given($res->code()){
		when(201) {
			return Crowd::Message->new(message => "User added to group");
		}
		when(400 or 403 or 404) {
			my $decoded = eval { JSON::Any->new()->jsonToObj($res->content()) };
			return Crowd::Error->new($decoded // {reason => "problem adding group membership", message => "Invalid response: $@"});
		}
		default {
			return Crowd::Message->new(message => "not sure what happened there...");
		}
	}
}

sub sso_session_uri {
	my ($self) = @_;
	
	return $self->crowd()->baseuri()."/session";
}

sub sso_session {
	my ($self, $password) = @_;
	
	return Crowd::Error->new({message => "Invalid password", reason => "Must either be authenticated, or supply a password"})
		unless ($self->authenticated() || defined($password));
	
	my $username = $self->name();
	my $passwordstr = defined($password) ? "<password>$password</password>" : "";
	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>
<authentication-context>
    <username>$username</username>
    $passwordstr
    <validation-factors>
        <validation-factor>
          <name>remote_address</name>
          <value>127.0.0.1</value>
        </validation-factor>
    </validation-factors>
</authentication-context>
};
	say "Going to send $xml";
	my $res = $self->crowd()->_postrequest( $self->sso_session_uri(),
	                                        { $self->authenticated() 
	                                          ? ('validate-password' => 0)
	                                          : (),
	                                        },
	                                        $xml );
	
	my $decoded = eval { JSON::Any->new()->jsonToObj($res->content())};
	if ($@) {
		return Crowd::Error->new(message => "Unable to get SSO session",
		                         reason => "$@",
		                        );
	}
	return Crowd::Session->new(%$decoded, crowd => $self->crowd());

}


no Mouse;
 
1;


