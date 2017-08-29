#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Cwd;
use XML::Simple;

use Gtk3 -init;
use Glib qw ( TRUE FALSE );

use Gtk3::Ex::DBI;
use Gtk3::Ex::DBI::Form;
use Gtk3::Ex::DBI::Datasheet;

use Database::Connection;
use Database::Connection::MySQL;
use Database::Connection::Postgres;
use Database::Connection::SQLite;

use powercom::config;
use powercom::configuration;
use powercom::dialog;
use powercom::pvoutput;
use powercom::viewer;

use config_manager;

my $windows = {};

my $current_dir = cwd;

use DBI;

my $globals = {
    config_dir  => $ENV{ HOME } . "/.powercom"
  , current_dir => $current_dir
  , builder_dir => $current_dir . "/builder"
  , windows     => \$windows
};

eval {

    $globals->{db} = Database::Connection::SQLite->new(
        $globals
      , {
            location    => $globals->{config_dir} . "/powercom.db"
        }
    ) || die();

};

if ( $@ ) {

    powercom::dialog::new(
        {
              title   => "Can't connect to database"
            , type    => "warning"
            , text    => "I can't make a connection to the local SQLite database!\n"
                       . "Please check that you have DBD::SQLite drivers installed and working.\n"
                       . "A detailed error message should be dumped to the console when this dialog closes ..."
        }
    );

    die( $@ );

}

eval {
    $globals->{db}->do(
        "create table if not exists connections (\n"
      . "    ID                integer primary key autoincrement\n"
      . "  , ConnectionName    text\n"
      . "  , Username          text\n"
      . "  , Password          text\n"
      . "  , Host              text\n"
      . "  , Port              text\n"
      . "  , Database          text\n"
      . ")"
    ) || die $globals->{db}->errstr;
};

my $err = $@;

if ( $err ) {

    powercom::dialog::new(
        {
              title   => "Error in SQLite config DB"
            , type    => "warning"
            , text    => $err
        }
    );

    die( $err );

}

my $opening_window_class = 'powercom::viewer';

$globals->{config_manager} = config_manager->new( $globals );

my $main_auth_values = $globals->{config_manager}->get_auth_values( 'main' );

if ( ! $main_auth_values ) {

    # TODO: add signal to call Gtk3->main_quit when config screen closes
    $opening_window_class = 'powercom::configuration';

} else {

    $main_auth_values->{Database} = 'powercom';
    $globals->{dbh} = Database::Connection::generate( $globals, $main_auth_values );
}

{
    
    $windows->{ $opening_window_class } = $opening_window_class->new( $globals );
    
    Gtk3->main;
    
}
