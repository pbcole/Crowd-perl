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

# Get some configuration items from an external source
my $config = { Config::General->new("crowd.properties")->getall() };

my $foo = Crowd->new({crowd_user => $config->{crowd}->{username}, crowd_password => $config->{crowd}->{password}});

ok($foo, "Can create an object");
isa_ok($foo, "Crowd", "Is the correct type");

my $res = $foo->authenticate($config->{realuser}->{username}, $config->{realuser}->{password});
is(ref($res), "Crowd::Error", "Authenticating a user not in a directory that can be used returns an Error object");
is($res->message(), "User is not allowed to authenticate with the application", "... Expected error message" );
is($res->reason(), "INVALID_USER_AUTHENTICATION", "... Expected reason given");



done_testing();
