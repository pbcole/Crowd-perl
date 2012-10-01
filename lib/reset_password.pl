#!/usr/bin/perl

use lib 'lib';
use strict;
use warnings;
use 5.10.1;

use Crowd;
my $foo = Crowd->new({crowd_user => 'philperl', crowd_password => 'philperl'});

my $philperl = $foo->lookup_user('philperl');
$philperl->change_password("testtest");
