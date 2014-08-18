package config_manager;

use strict;
use warnings;

sub new {
    
    my ( $class, $globals ) = @_;
    
    my $self;
    $self->{globals} = $globals;
    bless $self, $class;
    
    $self->{globals}->{db}->do(
        "create table if not exists simple_config (\n"
      . "    ID integer primary key autoincrement\n"
      . "  , key    text\n"
      . "  , value  text\n"
      . ")"
    );
    
    $self->{exists_simple_config} = $self->{globals}->{db}->prepare(
        "select ID, value from simple_config where key = ?"
    );
    
    $self->{update_simple_config} = $self->{globals}->{db}->prepare(
        "update simple_config set value = ? where ID = ?"
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
        
        $self->{update_simple_config}->execute( $value, $exists->{ID} );
        
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
    
    my ( $self, $db_name ) = @_;
    
    my $host_env = $self->simpleGet( $db_name . "_HOST_ENV" );
    
    my $username = $self->simpleGet( $db_name . "_" . $host_env . "_Username" );
    my $password = $self->simpleGet( $db_name . "_" . $host_env . "_Password" );
    my $host     = $self->simpleGet( $db_name . "_" . $host_env . "_Host" );
    my $driver   = $self->simpleGet( $db_name . "_" . $host_env . "_Driver" );
    
    my $values_hash = {
        Username    => $username
      , Password    => $password
      , Host        => $host
      , Driver      => $driver
    };
    
    if ( $db_name eq 'NZ' ) {
        my $port = $self->simpleGet( $db_name . "_" . $host_env . "_Port" );
        $values_hash->{Port} = $port;
    }
    
    return $values_hash;
    
}

1;
