package Database::Connection::MySQL;

use parent 'Database::Connection';

use strict;
use warnings;

use feature 'switch';

use Exporter qw ' import ';

our @EXPORT_OK = qw ' UNICODE_FUNCTION LENGTH_FUNCTION SUBSTR_FUNCTION ';

use constant UNICODE_FUNCTION   => 'hex';
use constant LENGTH_FUNCTION    => 'length';
use constant SUBSTR_FUNCTION    => 'substr';

use Glib qw | TRUE FALSE |;

sub connect {
    
    my ( $self, $auth_hash ) = @_;
    
    # We *always* rebuild the connection string for MySQL, as we have to
    # include the database in the connection string
    $auth_hash->{ConnectionString} = $self->build_connection_string( $auth_hash );
    
    eval {
        $self->{connection} = DBI->connect(
            $auth_hash->{ConnectionString}
          , $auth_hash->{Username}
          , $auth_hash->{Password}
        ) || die( $DBI::errstr );
    };
    
    my $err = $@;
    
    if ( $err ) {
        $self->dialog(
            {
                title   => "Failed to connect to database"
              , type    => "error"
              , text    => $err
            }
        );
        return undef;
    }

    my $sth = $self->prepare( 'select @@BASEDIR as BASEDIR' )
        || return;

    $self->execute( $sth )
        || return;

    my $row = $sth->fetchrow_hashref;

    if ( $row->{BASEDIR} =~ /rdsdbbin/ ) {
        $self->{is_rds} = 1;
    } else {
        $self->{is_rds} = 0;
    }

    #$self->{connection}->{FetchHashKeyName} = "NAME_uc";
    
    return 1;
    
}

sub build_connection_string {
    
    my ( $self, $auth_hash ) = @_;
    
    no warnings 'uninitialized';
    
    my $string =
          "dbi:mysql:"
        . "database="  . ( $auth_hash->{Database} || 'information_schema' )
        . ";host="       . $auth_hash->{Host}
        . ";port="      . ( $auth_hash->{Port} || 3306 );
    
    return $self->SUPER::build_connection_string( $auth_hash, $string );
    
}

sub connection_label_map {

    my $self = shift;

    return {
        Username        => "Username"
      , Password        => "Password"
      , Database        => ""
      , Host_IP         => "Host / IP"
      , Port            => "Port"
      , Attribute_1     => ""
      , Attribute_2     => ""
      , Attribute_3     => ""
      , Attribute_4     => ""
      , Attribute_5     => ""
    };

}

1;
