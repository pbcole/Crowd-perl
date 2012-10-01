#!/usr/bin/perl

use 5.10.1;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Deep;

use_ok("Crowd", "Can use the module ok");
use_ok("Crowd::User", "Can use the User module ok");
use_ok("Crowd::Message", "Can use the Message module ok");

use Data::Dumper;
use Data::Dump qw/dump/;

my $foo = Crowd->new({crowd_user => 'perlmodule', crowd_password => 'perlperl'});

ok($foo, "Can create an object");
isa_ok($foo, "Crowd", "Is the correct type");

my $res = $foo->authenticate("phil", "philphil");
is(ref($res), "Crowd::Error", "Authenticating a user not in a directory that can be used returns an Error object");
is($res->message(), "User is not allowed to authenticate with the application", "... Expected error message" );
is($res->reason(), "INVALID_USER_AUTHENTICATION", "... Expected reason given");

$res = $foo->authenticate("test", "testtest");
is(ref($res), "Crowd::User", "Authenticating a valid user returns a Crowd::User object");
diag "Valid log in returned: ";
print_results($res);

$res = $foo->lookup_user("test");
is(ref($res), "Crowd::User", "Looking up a valid user returns a Crowd::User object");
my $groups = $res->groups();
print_results($_) foreach (@$groups);

cmp_deeply([map {$_->name()} @$groups], [qw/foo/], "Returned groups as expected when going for direct groups");

$groups = $res->groups(1); # nested
cmp_deeply([map {$_->name()} @$groups], [qw/bah foo/], "Returned groups as expected when going for nested groups");

$res = $res->delete_group_membership('foo');
ok($res, "Deleting a group returns as expected");

$res = $foo->lookup_user("test");
ok(!$res->is_memberof('foo'), "No longer member of 'foo' group");

$res = $foo->lookup_user("test");
is(ref($res), "Crowd::User", "Looking up a user returns a Crowd::User object");
diag "User lookup: ";
print_results($res);

$res = $foo->lookup_user("test");
$res = $res->add_group_membership('foo');
is(ref($res), "Crowd::Message", "Adding group membership worked");

$res = $foo->lookup_user("test");
$res = $res->add_group_membership('foobah');
is(ref($res), "Crowd::Error", "Adding a non existent group results in error");


foreach my $group (@$groups) {
	print_results($_) foreach @{$group->members() || []};
}

$res = $foo->lookup_user("test");

ok($res->is_memberof('foo'), "is_memberof returns true when is a member of the group");
ok(!$res->is_memberof('bah'), "is_memberof Returns false when not a member of a group ");
ok($res->is_memberof('bah', 1), "is_memberof Returns false when not a member of a group ");

$res = $foo->lookup_user("test", 1);

$res = $foo->add_user({user => {
	'name' => 'philfoo',
	'first-name' => 'Phil',
	'last-name' => 'Foo',
	'display-name' => 'Phil Foo',
	'email' => 'phil@foo.com',
	'password' => 'philfoo',
	}
	});

is(ref($res), "Crowd::User", "Created a user and returned a Crowd::User object");
print_results($res);


$res = $foo->delete_user('philfoo');

is($res->code(), 204, "Deleted user OK");

$res = $foo->lookup_user('philfoo');
print_results($res);

my $test = $foo->lookup_user('test');
$res = $test->change_password('foobahbaz');
is(ref($res), "Crowd::User", "Change password returned as expected");

$res = $foo->authenticate("test", "testtest");
is(ref($res), "Crowd::Error", "Can't authenticate with old password anymore");
$res = $foo->authenticate("test", "foobahbaz");
is(ref($res), "Crowd::User", "Can authenticate with new password");

# reset the password back to what it should be (to allow the tests above to complete successfully
$test->change_password("testtest");

$res = $foo->send_password_reset("test");
is(ref($res), "Crowd::Message", "Password reset message sent");
print_results($res);
$res = $foo->send_password_reset("testblah");
is(ref($res), "Crowd::Error", "Password reset message can't be sent for unknown user");
print_results($res);

$res = $foo->send_usernames_for_email('pb.cole@gmail.com');
is(ref($res), "Crowd::Message", "Usernames for email sent");
print_results($res);
$res = $foo->send_usernames_for_email('foo@wibbleblah.com');
is(ref($res), "Crowd::Error", "Can't send usernames for unknown email");
print_results($res);

$res = $foo->authenticate("test", "testtest");
$DB::single = 1;
$res->sso_session();

print_results($res);

my $user = Crowd::User->new(name => 'test', crowd => $foo);
ok($user, "Created a user object");
is(ref($user), "Crowd::User", "... and it's the right type");

diag "Try to get sso Session without password - should fail";
$res = $user->sso_session();
print_results($res);

diag "Try to get sso session with password - should work";
$res = $user->sso_session('testtest');
print_results($res);

$res->get_token();

$res->validate_token();

my $message = Crowd::Message->new(message => "this is a message");
is($message, "this is a message", "Message is stringified as expected");



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
			print "Unaware of what to do with a ".ref($res)."\n";
		}
	}
}

sub print_userdetails {
	my $res = shift;

	print Dumper({ map { $_ => $res->$_ } ('name', 'firstname', 'lastname', 'email', 'displayname')}); #'groups')});
}

sub print_groupdetails {
	my $res = shift;
	
	say "Group name: ". $res->{name};
}

sub print_error {
	my $res = shift;
	print "**ERROR**: ".$res->reason()." - ".$res->message()."\n";
	
}
#http://crowd:8095/crowd/rest/usermanagement/latest/authentication?username=test
