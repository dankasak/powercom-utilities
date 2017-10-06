#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use WWW::Mechanize;

use Data::Dumper;

use constant LOGIN_URL          => 'https://secure.powershop.com.au/';
use constant USAGE_REPORT_URL   => 'https://secure.powershop.com.au/usage_report';

# Change these next 4 lines ...
use constant EMAIL              => 'me@some_domain.org';
use constant PASSWORD           => 'my_password_here';

my $from = '23/09/2017;
my $to   = '24/09/2017';

my $mech = WWW::Mechanize->new(
    cookie_jar      => {},
    autocheck       => 1,
    onerror         => \&Carp::croak,);

# Login Form
my $response = $mech->get( LOGIN_URL );

if( ! $response->is_success ) {
    die "Login page unreachable: ",  $response->status_line, "\n";
}

$mech->field( 'email', EMAIL );
$mech->field( 'password', PASSWORD );

$response = $mech->click();

if ($response->is_success) {
    print "Login Successful!\n";
} else {
    die "Login failed: ",  $response->status_line, "\n";
}

$response = $mech->get( USAGE_REPORT_URL );

print "\n\n" . Dumper( $response ) . "\n\n";

if( ! $response->is_success ) {
    die "Usage report page unreachable: ",  $response->status_line, "\n";
}

my $form = $mech->form_with_fields( 'from', 'to' );
$mech->field( 'from', '23/09/2017' );
$mech->field( 'to', '24/09/2017' );

$response = $mech->click();

if ($response->is_success) {
    print "Login Successful!\n";
} else {
    die "Login failed: ",  $response->status_line, "\n";
}

print Dumper( $response );
