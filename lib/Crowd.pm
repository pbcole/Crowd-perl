package Crowd;

use strict;
use warnings;

use Mouse;

use 5.10.1;
use LWP::UserAgent;
use JSON::Any;
use Data::Dumper;
use Data::Dump qw/dump/;

use Module::Find;
#my @modules = useall Crowd;
use Crowd::User;
use Crowd::Error;
use Crowd::Message;

use XML::Simple;

has 'userAgent' => ( is => 'ro', lazy_build => 1, );
has server => ( is => 'ro', default => 'crowd', required => 1, );
has port => ( is => 'ro', default => 8095, required => 1, );
has baseurl => ( is => 'ro', default => '/crowd/rest' );
has crowd_user => ( is => 'ro', required => 1 );
has crowd_password => ( is => 'ro', required => 1 );

sub _build_userAgent {
	my $lwp = LWP::UserAgent->new();
	return $lwp;
}

has rest_version => (is => 'ro', default => 'latest');
has user_lookup_uri => (is => 'ro', isa => 'Str', lazy_build => 1);
has baseuri => (is => 'ro', isa => 'Str', lazy_build => 1);
#has uri => (is => 'ro', isa => 'URI', lazy_build => 1, clearer => 'clear_uri', );
has scheme => (is => 'ro', isa => 'Str', default => 'http');

has curr_user => (is => 'rw', isa => "Maybe[Crowd::User]", clearer => 'clear_curr_user');

has password_reset_uri => (is => 'ro', isa => 'Str', lazy_build => 1);
has usernames_for_email_uri => (is => 'ro', isa => 'Str', lazy_build => 1);

sub uri {
	my $self = shift;
	my $uri = URI->new();

	#my $_addr = "http://".$self->server().":".$self->port().$self->baseurl().$addr;
	$uri->scheme($self->scheme());
	$uri->host($self->server());
	$uri->port($self->port());
	$uri->path($self->baseurl());

	return $uri;
}

sub user_auth_uri {
	my $self = shift;
	return $self->baseuri()."/authentication";
}

sub user_group_uri {
	my ($self, $nested) = @_;
	
	return $self->baseuri().'/user/group/'.($nested ? "nested" : "direct"); 
}

sub _build_user_lookup_uri {
	my $self = shift;
	return $self->baseuri()."/user";
}

sub _build_password_reset_uri {
	my $self = shift;
	return $self->baseuri()."/user/mail/password";
}

sub _build_usernames_for_email_uri {
	my $self = shift;
	return $self->baseuri()."/user/mail/usernames";
}

sub _build_baseuri {
	return "/usermanagement/".(shift->rest_version());
}

sub lookup_user {
	my $self = shift;
	my $username = shift;
	my $attributes = shift;

	my $addr = $self->user_lookup_uri();
	
	
	my $res = $self->_getrequest($addr, {username => $username, $attributes ? (expand => 'attributes') : ()});
	my $returned_data = eval { JSON::Any->new()->jsonToObj($res->content()) };

	if ($res && !$@) {
		if ($res->is_success()) {
			dump $res->content() if ($attributes);
			$self->curr_user(Crowd::User->new({%$returned_data, crowd => $self}));
			return $self->curr_user();
		}
		else {
			$self->clear_curr_user();
			return Crowd::Error->new($returned_data);
		}
	}
	else {
		$self->clear_curr_user();
		return Crowd::Error->new({reason => "can't get request, eval: $@", message => "Can't get user details"});
	}
	
}

sub delete_user {
	my ($self, $username) = @_;
	
	my $addr = $self->user_lookup_uri();
	
	my $res = $self->_deleterequest($addr, {username => $username}); 
	
	return $res;
	
}

sub add_user {
	my ($self, $details) = @_; 
	
	my $addr = $self->user_lookup_uri();
	
	return Crowd::Error->new({reason => "missing user data structure", message => "Missing user data structure"}) unless $details->{user};
	foreach my $field ('name', 'first-name', 'last-name', 'display-name', 'email', 'password') {
		return Crowd::Error->new({reason => "missing field '$field'", message => "Missing user data field"}) unless $details->{user}->{$field};
	}
	my $password = $details->{user}->{password};
	unless (ref($password) eq 'HASH') {
		$details->{user}->{password} = { "value" => $password },
	}
	
	(my ($username, $firstname, $lastname, $displayname, $email), $password) 
	    = @{$details->{user}}{('name', 'first-name', 'last-name', 'display-name', 'email', 'password')};
	
	$password=$password->{value};
	$details=qq{<?xml version="1.0" encoding="UTF-8"?>
  <user name="$username" expand="attributes">
  <first-name>$firstname</first-name>
  <last-name>$lastname</last-name>
  <display-name>$displayname</display-name>
  <email>$email</email>
  <active>true</active>
  <attributes>
    <link rel="self" href="http://crowd:8095/crowd/rest/usermanagement/latest/user/attribute?username=$username"/>
  </attributes>
  <password>
    <link rel="edit" href="http://crowd:8095/crowd/rest/usermanagement/latest/user/password?username=$username"/> <!-- /user/password?username=<username> -->
    <value>$password</value> <!-- only used when creating a user, otherwise not filled in -->
  </password>
</user>};
	
	my $res = $self->_postrequest($addr, {}, $details); 

	if ($res) {
		if ($res->is_success()) {
			return $self->lookup_user($username);
		}
		else {
			$self->clear_curr_user();
			return Crowd::Error->new({response => "blah", message => "foo"});
		}
	}
	else {
		$self->clear_curr_user();
		return Crowd::Error->new({reason => "can't get request, eval: $@", message => "Can't get user details"});
	}
	
}

=foo

VAR1 = {
          'link' => {
                      'rel' => 'self',
                      'href' => 'http://crowd:8095/crowd/rest/usermanagement/latest/user?username=philperl'
                    },
          'active' => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' ),
          'name' => 'philperl',
          'last-name' => 'Test',
          'display-name' => 'Phil Test',
          'email' => 'pb.cole@gmail.com',
          'password' => {
                          'link' => {
                                      'rel' => 'edit',
                                      'href' => 'http://crowd:8095/crowd/rest/usermanagement/latest/user/password?username=philperl'
                                    }
                        },
          'first-name' => 'Phil',
          'expand' => 'attributes',
          'attributes' => {
                            'link' => {
                                        'rel' => 'self',
                                        'href' => 'http://crowd:8095/crowd/rest/usermanagement/latest/user/attribute?username=philperl'
                                      },
                            'attributes' => []
                          }
        };

=cut

sub get_groups {
	my ($self) = @_;

	
	
}

sub _deleterequest {
	my ($self, $addr, $options) = @_;
	
	my $res = $self->_make_request('DELETE', $addr, $options, ''); 
	print "returned: ".$res->as_string();
	return $res;
}

sub _putrequest {
	my ($self, $addr, $options, $body) = @_;
	
	my $bodyxml = ref($body) eq 'HASH' ? XMLout($body, KeepRoot => 1, NoAttr => 1, ) : $body;
	my $res = $self->_make_request('PUT', $addr, $options, $bodyxml);
	say "returned: ".$res->as_string();
	return $res;
}

sub _postrequest {
	my ($self, $addr, $options, $body) = @_;

	my $password = $options->{password};
	my $bodyxml = ref($body) eq 'HASH' ? XMLout($body,  KeepRoot => 1, NoAttr => 1, ) : $body;
	my $res = $self->_make_request('POST', $addr, $options, $bodyxml); 
	print "returned: ".$res->as_string();
	return $res;
}

sub _getrequest {
	my ($self, $addr, $options) = @_;
	
	my $res = $self->_make_request('GET', $addr,  $options, '');

	say "returned: ".$res->as_string();
	return $res;
}

sub _make_request {
	my ($self, $scheme, $addr, $options, $body) = @_;

	my $_addr;
	my $ua = $self->userAgent();

	my $url = $self->uri();
	$_addr = join('/', ($self->baseurl(), $addr));
	$_addr =~ s{/+}{/}g;
	$url->path($_addr);

	delete $options->{password};
	$url->query_form(%$options);
	#say "have come from ".dump([caller()])." with options = ".dump($options);
	#say "url is $url";
	my $req = HTTP::Request->new($scheme => $url);

	$req->header("Accept" => "application/json");
	$req->authorization_basic($self->crowd_user(), $self->crowd_password()); #'philperl', 'philperl');
	if ($body) {
		$req->content_type("application/xml");
		$req->header('Content-Length' => length($body));
		$req->content($body);
	}
	#say "About to send request ".$req->as_string();
	return $ua->request($req);
}

sub authenticate {
	my ($self, $user, $password) = @_;

	my $addr = $self->user_auth_uri();
#	say "... Got addr to be $addr";
	my $res = $self->_postrequest($addr, {username => $user, }, { password => {value => $password}});
	# decode the JSON block returned
	
	if ($res) {
		my $returned_data = JSON::Any->new()->jsonToObj($res->content());
		if ($res->is_success()) {
			return Crowd::User->new({%$returned_data, authenticated => 1, crowd => $self});
		}
		else {
			return Crowd::Error->new($returned_data);
		}
	}
	else {
		return { content => $res->content() };
	}
}

sub send_password_reset {
	my ($self, $username) = @_;
	
	my $addr = $self->password_reset_uri();
	my $res = $self->_postrequest($addr, {username => $username}, "");
	say "returned message was ".$res->content();
	given($res->code()) {
		when(204) {
			return Crowd::Message->new(message => "Password reset mail sent");
		}
		when(404) {
			return Crowd::Error->new(message => "User not found", reason => "User not found");
		}
		default {
			return Crowd::Error->new(message => "Unable to sent email", reason => "insufficient privileges");
		}
	}
}

sub send_usernames_for_email {
	my ($self, $emailaddr) = @_;
	
	my $res = $self->_postrequest($self->usernames_for_email_uri(), {email => $emailaddr}, "");
	say "send usernames request returned message: ".$res->content();
	given($res->code()) {
		when(204) {
			return Crowd::Message->new(message => "Usernames for the email address sent");
		}
		when(404) {
			return Crowd::Error->new(message => "User not found", reason => "User not found");
		}
		default {
			return Crowd::Error->new(message => "Unable to send usernames", reason => "insufficient privileges");
		}
	}
}

sub create_sso_session {
	my ($self) = @_;
	
	
}

no Mouse;
1;

