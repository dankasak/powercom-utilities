package Database::Connection::Postgres;

use parent 'Database::Connection';

use strict;
use warnings;

use feature 'switch';

use Exporter qw ' import ';

use Time::HiRes;

our @EXPORT_OK = qw ' UNICODE_FUNCTION LENGTH_FUNCTION SUBSTR_FUNCTION ';

use constant UNICODE_FUNCTION   => 'unicodes';
use constant LENGTH_FUNCTION    => 'length';
use constant SUBSTR_FUNCTION    => 'substr';

use Glib qw ' TRUE FALSE ';

sub new {
    
    my $self = shift->SUPER::new( @_ );
    
    if ( ! $self ) {
        return undef;
    }
    
    return $self;
    
}

sub connect {
    
    my ( $self, $auth_hash, $options_hash ) = @_;
    
    # We *always* rebuild the connection string for Postgres, as we have to
    # include the database in the connection string
    $auth_hash->{ConnectionString} = $self->build_connection_string( $auth_hash );
    
    my $dbi_options_hash = {
                               RaiseError        => 0
                             , AutoCommit        => 1
                           };
    
    # TODO: case handling ...
    # To maintain compatibility with Netezza ( which returns column names in UPPER CASE ),
    # we started using the below FetchHashKeyName hack to make other databases to the same.
    # This causes issues ( eg fetching primary key info from postgres, and also matching column names
    # returned by db-specific 'fetch column' SQL with column names returned by queries ).
    # We need to remove this and implement column name mangling explicitely and ONLY in the cases where we need it.
    
    eval {
        $self->{connection} = DBI->connect(
            $auth_hash->{ConnectionString}
          , $auth_hash->{Username}
          , $auth_hash->{Password}
          , $dbi_options_hash
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
    
    return 1;
    
}

sub build_connection_string {
    
    my ( $self, $auth_hash ) = @_;
    
    if ( ! $auth_hash->{Database} || $auth_hash->{Database} eq '+ Add New Database' ) {
        $auth_hash->{Database} = $self->default_database; # Postgres requires you to specify a database when connecting ...
    }
    
    if ( ! $auth_hash->{Port} ) {
        $auth_hash->{Port} = 5432;
    }
    
    no warnings 'uninitialized';
    
    my $string =
          "dbi:Pg:dbname=" . $auth_hash->{Database}
        . ";host="         . $auth_hash->{Host}
        . ";port="         . $auth_hash->{Port};
    
    return $self->SUPER::build_connection_string( $auth_hash, $string );
    
}

sub connection_label_map {
    
    return {
        Username        => "Username"
      , Password        => "Password"
      , Host_IP         => "Host / IP"
      , Port            => "Port"
      , Database        => ""
      , Attribute_1     => ""
      , Attribute_2     => ""
      , Attribute_3     => ""
      , Attribute_4     => ""
      , Attribute_5     => ""
    };
    
}

sub default_database {
    
    my $self = shift;
    
    return 'postgres';
    
}

1;
