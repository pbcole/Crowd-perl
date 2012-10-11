#!/usr/bin/perl

use 5.10.1;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Config::General;

use Test::More;
use Test::Deep;

use_ok("Crowd", "Can use the module ok");
use_ok("Crowd::User", "Can use the User module ok");
use_ok("Crowd::Message", "Can use the Message module ok");

use Data::Dumper;
use Data::Dump qw/dump/;

use Try::Tiny;

# Get some configuration items from an external source
my $config = { Config::General->new( -ConfigFile => "crowd.properties", -ForceArray => 1, )->getall() };

# Let's make sure that we can create a user by supplying the required basic details.
my $working_connection = Crowd->new({crowd_user => $config->{crowd}->{username}, crowd_password => $config->{crowd}->{password}});
ok($working_connection, "Can create an object");
isa_ok($working_connection, "Crowd", "Is the correct type");


my $broken_connection;
eval {
	$broken_connection = Crowd->new(); # provide no details
};
like($@, qr{Attribute \(crowd_user\) is required}m, "Spotted that crowd_user attribute wasn't specified");
ok(!$broken_connection, "Can't create a connection if we don't supply any details to connect to the Crowd application");

eval {
	$broken_connection = Crowd->new(crowd_user => $config->{crowd}->{username});
};
like($@, qr{Attribute \(crowd_password\) is required}m, "Spotted that crowd_password attribute wasn't specified");
ok(!$broken_connection, "Can't create a connection if we only supply a username to connect to the Crowd application");

eval {
	$broken_connection = Crowd->new(crowd_user => $config->{crowd}->{username}, crowd_password => $config->{crowd}->{password}, crowd_server => 'foo' );
};
#like($@, qr{Attribute \(crowd_password\) is required}m, "Spotted that crowd_password attribute wasn't specified");
ok($broken_connection, "Can create a connection even if we supply an invalid server to connect to the Crowd application");


#diag "\$\@ has been returned as $@";


################
## Test whether we can authenticate or not
my $res = $working_connection->authenticate($config->{realuser}->{username}, $config->{realuser}->{password});
is(ref($res), "Crowd::Error", "Authenticating a user not in a directory that can be used returns an Error object");
is($res->message(), "User is not allowed to authenticate with the application", "... Expected error message" );
is($res->reason(), "INVALID_USER_AUTHENTICATION", "... Expected reason given");

# side step... can we connect via https?
my $https_connection = Crowd->new({crowd_user => $config->{crowd}->{username}, 
                                   crowd_password => $config->{crowd}->{password}, 
                                   scheme => 'https', 
                                   port => 8443, 
                                  });
ok($https_connection, "Can create an object when using https scheme");
isa_ok($https_connection, "Crowd", "Is the correct type");
$res = $https_connection->authenticate($config->{realuser}->{username}, $config->{realuser}->{password});
is(ref($res), "Crowd::Error", "Authenticating a user not in a directory that can be used returns an Error object");
is($res->message(), "User is not allowed to authenticate with the application", "... Expected error message" );
is($res->reason(), "INVALID_USER_AUTHENTICATION", "... Expected reason given");


$res = $working_connection->authenticate($config->{testuser}->{username}, $config->{testuser}->{password});
is(ref($res), "Crowd::User", "Authenticating a valid user returns a Crowd::User object");
diag "Valid login returned: ";
print_results($res);

$res = $https_connection->authenticate($config->{testuser}->{username}, $config->{testuser}->{password});
is(ref($res), "Crowd::User", "Authenticating a valid user returns a Crowd::User object when using https");
diag "Valid login returned: ";
print_results($res);
done_testing();
exit 0;

$res = $working_connection->lookup_user($config->{testuser}->{username});
is(ref($res), "Crowd::User", "Looking up a valid user returns a Crowd::User object");
my $groups = $res->groups();
print_results($_) foreach (@$groups);

cmp_deeply([map {$_->name()} @$groups], $config->{testuser}->{groups}, "Returned groups as expected when going for direct groups");

$groups = $res->groups(1); # nested
cmp_deeply([map {$_->name()} @$groups], $config->{testuser}->{nestedgroups}, "Returned groups as expected when going for nested groups");



done_testing();


sub print_results {
	my $res = shift;
	given(ref($res)) {
		when ('Crowd::User') {
			print_userdetails($res);
		}
		when ('Crowd::Group') {
			print_groupdetails($res);
		}
		when ('Crowd::Error') {
			print_error($res);
		}
		when ("Crowd::Message") {
			say "message: ".$res; #->message();
		}
		when ("Crowd::Session") {
			say "Session token: ".$res;
		}
		default {
			say "Unaware of what to do with a ".ref($res);
		}
	}
}

sub print_userdetails {
	my $res = shift;

	say Dumper({ map { $_ => $res->$_ } ('name', 'firstname', 'lastname', 'email', 'displayname')}); #'groups')});
}

sub print_groupdetails {
	my $res = shift;
	
	say "Group name: ". $res->{name};
}

sub print_error {
	my $res = shift;
	say "**ERROR**: ".$res->reason()." - ".$res->message();
	
}

