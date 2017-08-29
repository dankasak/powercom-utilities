package Database::Connection;

use parent 'window';

use strict;
use warnings;

use feature 'switch';

use Text::CSV;
use Glib qw | TRUE FALSE |;

use Carp;

use vars qw ' $AUTOLOAD ';

use constant    PERL_ZERO_RECORDS_INSERTED      => '0E0';

sub AUTOLOAD {
    
    my ( $self, @args ) = @_;
    
    # Perl is cool ;) What we're doing here is catching any method calls that we don't implement ourself,
    # and passing them through to the connection object
    
    my $method = $AUTOLOAD;
    
    # strip out our own class, which will leave the method name we should pass through to DBI ...
    my $class = ref $self;
    $method =~ s/$class\:\://;
    
    if ( $class && exists $self->{connection} ) { # otherwise we get errors during global destruction
        return $self->{connection}->$method( @args );
    }
    
}

sub generate {
    
    my ( $globals, $auth_hash, $dont_connect, $config_manager_type, $progress_bar, $options_hash ) = @_;
    
    # This STATIC FUNCTION ( not a method ) will determine which subclass of
    # Database::Connection we need, and construct an object of that type
    
    my $connection_class        = $auth_hash->{DatabaseType};
    
    my $object_class            = 'Database::Connection::' . $connection_class;
    
    my $connection_object       = $object_class->new(
        $globals
      , $auth_hash
      , $dont_connect
      , $progress_bar
      , $options_hash
    );
    
    if ( $config_manager_type ) {
        
        my $config_manager_class = "Database::ConfigManager::" . $connection_class;
        
        $connection_object->{config_manager} = window::generate(
            $globals
          , $config_manager_class
          , $connection_object
          , $config_manager_type
        );
        
    }
    
    return $connection_object;
    
}

sub connection_type {
    
    my $self = shift;
    
    my $full_class = ref $self;
    
    $full_class =~ /.*::([\w]*)/;
    
    return $1;
    
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

sub new {
    
    my ( $class, $globals, $auth_hash, $dont_connect, $progress_bar, $options_hash ) = @_;
    
    my $self;
    
    $self->{globals} = $globals;
    
    bless $self, $class;
    
    $self->{progress_bar} = $progress_bar;
    
    if ( $dont_connect ) {
        return $self;
    } else {
        if ( $self->connect( $auth_hash, $options_hash ) ) {
            $self->{database}  = $auth_hash->{Database}; # It's handy to remember this for later - some DBs have metadata queries that only provide info for the active database
            $self->{auth_hash} = $auth_hash;
            return $self; 
        } else {
            return undef;
        }
    }
    
}

sub connect {
    
    my ( $self, $auth_hash ) = @_;
    
    if ( ! $auth_hash->{ConnectionString} ) {
        $auth_hash->{ConnectionString} = $self->build_connection_string( $auth_hash );
    }
    
    eval {
        $self->{connection} = DBI->connect(
            $auth_hash->{ConnectionString}
          , $auth_hash->{Username}
          , $auth_hash->{Password}
          , {
              RaiseError    => 0
            , AutoCommit    => 1
            }
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
    
    my ( $self, $auth_hash, $connection_string ) = @_;
    
    if ( $auth_hash->{UseProxy} ) {
        
        if ( ! $auth_hash->{ProxyAddress} ) {
            
            $self->dialog(
                {
                    title       => "Proxy configuration missing"
                  , type        => "error"
                  , text        => "The UseProxy flag is set, but there is no ProxyAddress!"
                }
            );
            
            return undef;
            
        } else {
            
            my ( $proxy_host, $proxy_port ) = split( /:/, $auth_hash->{ProxyAddress} );
            
            $connection_string = "dbi:Proxy:hostname=$proxy_host;port=$proxy_port;dsn=$connection_string";
            
        }
        
    }
    
    return $connection_string;
    
}

sub default_database {
    
    my $self = shift;
    
    warn $self->connection_type . " doesn't implement default_database()";
    
    return undef;
    
}

sub connection {
    
    my $self = shift;
    
    return $self->{connection};
    
}

sub prepare {
    
    my ( $self, $sql ) = @_;
    
    my $sth;
    
    eval {
        $sth = $self->{connection}->prepare( $sql )
            || confess( $self->{connection}->errstr );
    };
    
    my $err = $@;
    
    if ( $err && ! $self->{globals}->{suppress_error_dialogs} ) {
        $self->dialog(
            {
                title   => "Failed to prepare SQL"
              , type    => "error"
              , text    => $err
            }
        );
        print "\n$sql\n";
        return undef;
    }
    
    $self->{last_prepared_sql} = $sql;
    
    return $sth;
    
}

sub execute {
    
    my ( $self, $sth, $bind_values ) = @_;
    
    my $result;
    
    eval {
        if ( defined $bind_values ) {
            $result = $sth->execute( @$bind_values )
                || confess( $sth->errstr );
        } else {
            $result = $sth->execute
                || confess( $sth->errstr );
        }
    };
    
    my $err = $@;
        
    if ( $err && ! $self->{globals}->{suppress_error_dialogs} ) {
        $self->dialog(
            {
                title   => "Failed to execute SQL"
              , type    => "error"
              , text    => $err
            }
        );
        print "\n" . $self->{last_prepared_sql} . "\n";
    }
    
    return $result;
    
}

sub do {
    
    my ( $self, $sql, $bind_values ) = @_;
    
    my $result;
    
    eval {
        
        if ( defined $bind_values ) {
            $result = $self->{connection}->do( $sql, undef, @$bind_values )
                or confess ( $self->{connection}->errstr );
        } else {
            $result = $self->{connection}->do( $sql )
                or confess ( $self->{connection}->errstr );
        }
        
    };
    
    my $err = $@;
    
    if ( $err && ! $self->{globals}->{suppress_error_dialogs} ) {
        $self->dialog(
            {
                title   => "Failed to execute SQL"
              , type    => "error"
              , text    => $err
            }
        );
        warn $sql;
    }
    
    return $result;
    
}

sub select {
    
    my ( $self, $sql, $bind_values, $key ) = @_;
    
    my $sth = $self->prepare( $sql )
        || return;
    
    if ( $bind_values ) {
        $self->execute( $sth, $bind_values )
            || return;
    } else {
        $self->execute( $sth )
            || return;
    }
    
    my $records;
    
    if ( $key ) {
        $records = $sth->fetchall_hashref( $key );
    } else {
        while ( my $row = $sth->fetchrow_hashref ) {
            push @{$records}, $row;
        }
    }
    
    $sth->finish;
    
    return $records;
    
}

1;
