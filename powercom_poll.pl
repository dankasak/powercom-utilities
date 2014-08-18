#!/usr/bin/perl

use warnings;
use strict;

use DBD::SQLite;
use Getopt::Long;
use File::Path;
use File::Copy;

use config_manager;

my $globals;

my $parse_file;

GetOptions( 
            'parse-file=s'              => \$parse_file
          );

$globals->{config_dir} = $ENV{ HOME } . "/.powercom";

if ( ! -e $globals->{config_dir} ) {
    eval { mkpath( $globals->{config_dir} ) };
    if ( $@ ) {
        die ( "Couldn't create configuration directory $globals->{config_dir}: $@\nThis is fatal ..." );
    }
}

if ( ! -e $globals->{config_dir} . "/processed" ) {
    eval { mkpath( $globals->{config_dir} . "/processed" ) };
    if ( $@ ) {
        die ( "Couldn't create configuration directory " . $globals->{config_dir} . "/processed" . ": $@\nThis is fatal ..." );
    }
}

$globals->{db} = DBI->connect(
    "dbi:SQLite:dbname=" . $globals->{config_dir} . "/powercom.db",
    "",
    ""
) || die $DBI::errstr;

my $config_manager = config_manager->new( $globals );

$globals->{db}->do(
    "create table if not exists readings (\n"
  . "    id                       integer primary key autoincrement\n"
  . "  , serial_number            number\n"
  . "  , reading_datetime         datetime\n"
  . "  , heat_sink_temperature    number\n"
  . "  , panel_1_voltage          number\n"
  . "  , panel_1_dc_voltage       number\n"
  . "  , working_hours            number\n"
  . "  , operating_mode           text\n"
  . "  , tmp_f_value              number\n"
  . "  , pv_1_f_value             number\n"
  . "  , gfci_f_value             number\n"
  . "  , fault_code_high          number\n"
  . "  , fault_code_low           number\n"
  . "  , line_current             number\n"
  . "  , line_voltage             number\n"
  . "  , ac_frequency             number\n"
  . "  , ac_power                 number\n"
  . "  , zac                      number\n"
  . "  , accumulated_energy       number\n"
  . "  , gfci_f_value_volts       number\n"
  . "  , gfci_f_value_hz          number\n"
  . "  , gz_f_value_ohm           number\n"
  . ")"
);

$globals->{db}->do(
    "create table if not exists daily_summary (\n"
  . "    id                           integer primary key autoincrement\n"
  . "  , reading_date                 date\n"
  . "  , max_heat_sink_temperature    number\n"
  . "  , max_ac_power                 number\n"
  . "  , total_ac_power               number\n"
  . "  , weather_condition            text\n"
  . "  , uploaded                     number\n"
  . "  , upload_status                text\n"
  . ")"
);

my $powercom_test_path = $config_manager->simpleGet( "powercom_test_path" );

if ( ! $powercom_test_path ) {
    $powercom_test_path = `which powercom-test`;
    if ( ! $powercom_test_path ) {
        die( "Couldn't find the powercom-test binary. Put it in your path, or configure the project with the path to the binary" );
    }
    $config_manager->simpleSet( "powercom_test_path", $powercom_test_path );
}

if ( $parse_file ) {
    parse_powercom_output( $parse_file );
} else {
    parse_powercom_output( get_powercom_registers() );
}

sub get_powercom_registers {
    
    my $timestamp = prettyTimestamp();
    my $output_path = $globals->{config_dir} . "/reading_" . $timestamp . ".txt";
    
    my $output = `$powercom_test_path`;
    
    open FH, ">$output_path"
        || die( "Failed to open file for writing:\n$!" );
    
    print FH $output;
    
    close FH;
    
    return $output_path;
    
}


sub parse_powercom_output {
    
    my $output_path = shift;
    
    open INPUT, $output_path
        || die( "Couldn't open the input file [$output_path]. Received:" . $! );
    
    my $reading_datetime;
    
    if ( $output_path =~ /reading_(\d*)_(\d*)/ ) {
        my $date = $1;
        my $time = $2;
        $reading_datetime = substr( $date, 0, 4 ) . "-" . substr( $date, 4, 2 ) . "-" . substr( $date, 6, 2 )
            . " " . substr( $time, 0, 2 ) . ":" . substr( $time, 2, 2 ) . ":" . substr( $time, 4, 2 );
    }
    
    my ( $heat_sink_temperature, $panel_1_voltage, $panel_1_dc_voltage, $working_hours
       , $operating_mode, $tmp_f_value, $pv_1_f_value, $gfci_f_value, $fault_code_high
       , $fault_code_low, $line_current, $line_voltage, $ac_frequency, $ac_power
       , $zac, $accumulated_energy, $gfci_f_value_volts, $gfci_f_value_hz, $gz_f_value_ohm
       , $serial_number, $working_hours_high_word, $working_hours_low_word
       , $accumulated_energy_high_word, $accumulated_energy_low_word );
    
    while ( my $line = <INPUT> ) {
        
        if ( $line =~ /serial\snumber\s(\d*)/ ) {
            
            $serial_number = $1;
            
        } elsif ( $line =~ /Register\s(\d*):\s(\d*)/ ) {
            
            my $register = $1;
            my $value    = $2;
            
            # There is probably a more graceful way of doing this, but anyway ...
            
            if (      $register == 0 ) {
                
                $heat_sink_temperature = $value / 10;
                
            } elsif ( $register == 1 ) {
                
                $panel_1_voltage = $value / 10;
                
            } elsif ( $register == 2 ) {
                
                $panel_1_dc_voltage = $value / 10;
                
            } elsif ( $register == 3 ) {
                
                $working_hours_high_word = $value;
                
            } elsif ( $register == 4 ) {
                
                $working_hours_low_word = $value;
                
            } elsif ( $register == 5 ) {
                
                $operating_mode = $value;
                
            } elsif ( $register == 6 ) {
                
                $tmp_f_value = $value / 10;
                
            } elsif ( $register == 7 ) {
                
                $pv_1_f_value = $value / 10;
                
            } elsif ( $register == 8 ) {
                
                $gfci_f_value = $value;
                
            } elsif ( $register == 9 ) {
                
                $fault_code_high = $value;
                
            } elsif ( $register == 10 ) {
                
                $fault_code_low = $value;
                
            } elsif ( $register == 11 ) {
                
                $line_current = $value / 10;
                
            } elsif ( $register == 12 ) {
                
                $line_voltage = $value / 10;
                
            } elsif ( $register == 13 ) {
                
                $ac_frequency = $value / 100;
                
            } elsif ( $register == 14 ) {
                
                $ac_power = $value;
                
            } elsif ( $register == 15 ) {
                
                $zac = $value / 1000;
                
            } elsif ( $register == 16 ) {
                
                $accumulated_energy_high_word = $value;
                
            } elsif ( $register == 17 ) {
                
                $accumulated_energy_low_word = $value;
                
            } elsif ( $register == 18 ) {
                
                $gfci_f_value_volts = $value / 10;
                
            } elsif ( $register == 19 ) {
                
                $gfci_f_value_hz = $value / 100;
                
            } elsif ( $register == 20 ) {
                
                $gz_f_value_ohm = $value / 1000;
                
            }
            
        } else {
            
            print "Ignoring line:\n$line";
            
        }
          
    }
    
    $working_hours = ( $working_hours_high_word * 6553.6 ) + ( $working_hours_low_word / 10 );
    $accumulated_energy = ( $accumulated_energy_high_word * 6553.6 ) + ( $accumulated_energy_low_word / 10 );
    
    if ( $accumulated_energy ) {
        
        my $insert_sth = $globals->{db}->prepare(
            "insert into readings ( serial_number, reading_datetime, heat_sink_temperature, panel_1_voltage\n"
          . "  , panel_1_dc_voltage, working_hours, operating_mode, tmp_f_value, pv_1_f_value, gfci_f_value\n"
          . "  , fault_code_high, fault_code_low, line_current, line_voltage, ac_frequency, ac_power\n"
          . "  , zac, accumulated_energy, gfci_f_value_volts, gfci_f_value_hz, gz_f_value_ohm ) values (\n"
          . " ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )"
        ) || die( $globals->{db}->errstr );
        
        $insert_sth->execute(
            $serial_number, $reading_datetime, $heat_sink_temperature, $panel_1_voltage
          , $panel_1_dc_voltage, $working_hours, $operating_mode, $tmp_f_value, $pv_1_f_value, $gfci_f_value
          , $fault_code_high, $fault_code_low, $line_current, $line_voltage, $ac_frequency, $ac_power
          , $zac, $accumulated_energy, $gfci_f_value_volts, $gfci_f_value_hz, $gz_f_value_ohm
        ) || die( $insert_sth->errstr );
        
    }
    
    close( INPUT );
    
    move( $output_path, $globals->{config_dir} . "/processed" );
    
}

sub prettyTimestamp {
    
    # This function returns the current time as a human-readable timestamp
    #  ... without having to install further date/time manipulation libraries
    
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    
    #               print mask ... see sprintf
    return sprintf( "%04d%02d%02d_%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec );
    
}
