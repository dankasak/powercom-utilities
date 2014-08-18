#!/usr/bin/perl

use strict;

use Carp;
use Cwd;
use XML::Simple;

use Gtk3 -init;
use Glib qw ( TRUE FALSE );

use Gtk3::Ex::DBI::Datasheet;

use powercom::config;
use powercom::dialog;
use powercom::pvoutput;
use powercom::viewer;

use config_manager;

my $forms = {};

my $current_dir = cwd;

use DBI;

my $globals = {
    config_dir  => $ENV{ HOME } . "/.powercom"
  , current_dir => $current_dir
  , builder_dir => $current_dir . "/builder"
  , forms       => \$forms
};

eval {
    $globals->{db} = DBI->connect(
        "dbi:SQLite:dbname=" . $globals->{config_dir} . "/powercom.db",
        "",
        ""
    ) || die $DBI::errstr;
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

$globals->{config_manager} = config_manager->new( $globals );

{
    
    $forms->{main} = powercom::viewer->new( $globals );
    
    Gtk3->main;
    
}
