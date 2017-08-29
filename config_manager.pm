package config_manager;

use strict;
use warnings;

use File::Find qw( finddepth );

sub new {
    
    my ( $class, $globals ) = @_;
    
    my $self;
    $self->{globals} = $globals;
    bless $self, $class;
    
    $self->{globals}->{db}->do(
        "create table if not exists simple_config (\n"
      . "    key    text         not null      primary key\n"
      . "  , value  text\n"
      . ")"
    );

    $self->{globals}->{db}->do(
        "create table if not exists connections (\n"
      . "    ID                integer primary key autoincrement\n"
      . "  , ConnectionName    text\n"
      . "  , DatabaseType      text\n"
      . "  , EnvironmentName   text\n"
      . "  , Username          text\n"
      . "  , Password          text\n"
      . "  , Host              text\n"
      . "  , Port              text\n"
      . ")"
    );

    $self->{exists_simple_config} = $self->{globals}->{db}->prepare(
        "select value from simple_config where key = ?"
    );
    
    $self->{update_simple_config} = $self->{globals}->{db}->prepare(
        "update simple_config set value = ? where key = ?"
    );
    
    $self->{insert_simple_config} = $self->{globals}->{db}->prepare(
        "insert into simple_config ( key, value ) values ( ?, ? )"
    );
    
    return $self;
    
}

sub simpleSet {
    
    my ( $self, $key, $value ) = @_;
    
    $self->{exists_simple_config}->execute( $key );
    
    my $exists = $self->{exists_simple_config}->fetchrow_hashref;
    
    if ( $exists ) {
        
        $self->{update_simple_config}->execute( $value, $exists->{key} );
        
    } else {
        
        $self->{insert_simple_config}->execute( $key, $value );
        
    }
    
}

sub simpleGet {
    
    my ( $self, $key ) = @_;
    
    $self->{exists_simple_config}->execute( $key );
    
    my $exists = $self->{exists_simple_config}->fetchrow_hashref;
    
    if ( $exists ) {
        
        return $exists->{value};
        
    } else {
        
        return undef;
        
    }
    
}

sub get_auth_values {

    my ( $self, $connection_name ) = @_;

    my $auth_hash = $self->{globals}->{db}->select(
        "select * from connections where ConnectionName = ?"
        , [ $connection_name ]
    );

    if ( ! $auth_hash ) {

        powercom::dialog::new(
            {
                  title       => "Couldn't find connection in config database!"
                , type        => "error"
                , markup      => "The config manager was requested to build auth values for:\n\n"
                               . "Connection Name:  [<span color='blue'><b>$connection_name</b></span>]\n"
                               . " ... but there is no such entry in the Connections table.\n"
                               . "Please open the configuration screen and add such a connection.\n\n"
                               . "<i>Expect a bunch of errors after this message ...</i>"
            }
        );

        return undef;

    }

    return $auth_hash->[0];

}

sub all_database_drivers {

    my $self = shift;

    my $db_class_path = $self->{globals}->{current_dir} . "/Database/Connection/";

    my ( @files , @all_database_drivers );

    finddepth(
        sub {
            return if($_ eq '.' || $_ eq '..');
            push @files, $File::Find::name;
        }
        , $db_class_path
    );

    foreach my $file ( @files ) {

        my $db_class_name;

        if ( $file =~ /.*Database\/Connection\/(.*)\.pm$/ ) {
            $db_class_name = $1;
            $db_class_name =~ s/\//::/g; # substitute slashes with ::
            push @all_database_drivers, $db_class_name;
        }

    }

    my @sorted_dbs = sort( @all_database_drivers );

    return \@sorted_dbs;

}

1;

1;
