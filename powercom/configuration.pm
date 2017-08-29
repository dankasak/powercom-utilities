package powercom::configuration;

use parent 'window';

use strict;
use warnings;

use Glib qw( TRUE FALSE );

sub new {
    
    my ( $class, $globals, $options ) = @_;
    
    my $self;
    
    $self->{globals} = $globals;
    $self->{options} = $options;
    
    bless $self, $class;
    
    $self->{builder} = Gtk3::Builder->new;
    $self->{builder}->add_objects_from_file( "$self->{globals}->{builder_dir}/configuration.glade", "main" );
    
    my $model = Gtk3::ListStore->new( "Glib::String", "Gtk3::Gdk::Pixbuf" );
    my $widget = $self->{builder}->get_object( 'DatabaseType' );

    my $database_types = $self->{globals}->{config_manager}->all_database_drivers;

    foreach my $db( @{$database_types} ) {
        
        my $icon_path = $self->{globals}->{current_dir} . "/icons/" . ( $db . '.png' );
        my $icon;
        
        if ( $icon_path ) {
            $icon = $self->to_pixbuf( $icon_path );
        }
        
        $model->set(
            $model->append
          , 0 , $db
          , 1, $icon
        );
        
    }
    
    $self->create_combo_renderers( $widget, 0, 1 );
    
    $widget->set_model( $model );
    
    $self->{connections_list} = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{db}
          , sql             => {
                                    pass_through    => "select ConnectionName\n"
                                                     . "from connections\n"
                                                     . "order by ConnectionName"
                               }
          , vbox            => $self->{builder}->get_object( 'current_connections_box' )
          , on_row_select   => sub { $self->on_connection_select( @_ ) }
        }
    );
    
    $self->{connections}        = Gtk3::Ex::DBI::Form->new(
        {
            dbh                 => $self->{globals}->{db}
          , debug               => 1
          , sql                 => {
                                        select          => "*"
                                      , from            => "connections"
                                   }
          , auto_incrementing   => 1
          , builder             => $self->{builder}
          , recordset_tools_box => $self->{builder}->get_object( 'connection_tools_box' )
          , on_changed          => sub { $self->on_connections_changed( @_ ) }
          , before_apply        => sub { print "applying ...\n" }
          , on_current          => sub { $self->{builder}->get_object( 'Password' )->set_visibility( FALSE ); }
          , on_apply            => sub { $self->{connections_list}->query }
          , on_initial_changed  => sub { $self->on_connections_initial_changed( @_ ) }
          , auto_tools_box      => 1
        }
    );
    
    # Create a button to test the connection ...
    my $button = Gtk3::Button->new_with_label( 'test ...' );
    my $icon   = Gtk3::Image->new_from_icon_name( 'gtk-dialog-question', 'button' );
    $button->set_image( $icon );
    $button->set( 'always-show-image', TRUE );
    $button->signal_connect( 'button-press-event', sub { $self->test_connection( @_ ) } );
    $self->{connections}->{recordset_tools_box}->pack_end( $button, TRUE, TRUE, 2 );
    $button->show;
    
    $self->{simple_local_config}  = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{db}
          , sql             => {
                                    select      => "ID, key, value"
                                  , from        => "simple_config"
                               }
          , fields          => [
                                    {
                                        name        => "ID"
                                      , renderer    => "hidden"
                                    }
                                  , {
                                        name        => "key"
                                      , x_percent   => 35
                                    }
                                  , {
                                        name        => "value"
                                      , x_percent   => 65
                                    }
                               ]
          , vbox            => $self->{builder}->get_object( "simple_config_local" )
          , auto_tools_box  => 1
        }
    );
    
    $self->{builder}->connect_signals( undef, $self );
    
    $self->on_DatabaseType_changed;

    return $self;
    
}

sub on_connection_select {
    
    my $self = shift;
    
    my $connection_name     = $self->{connections_list}->get_column_value( "ConnectionName" );

    $self->{connections}->query(
        {
            where       => "ConnectionName = ?"
          , bind_values => [ $connection_name ]
        }
    );
    
}

sub on_connections_initial_changed{
    
    my $self = shift;
    
#    if ( ! $self->{connections}->get_widget_value( "EnvironmentName" ) ) {
#        $self->{connections}->set_widget_value( "EnvironmentName", $self->{builder}->get_object( 'ENV_CODE' )->get_text );
#    }
    
    return TRUE;
    
}

sub get_auth_hash {
    
    my $self = shift;
    
    my $auth_hash = {
        Username            => $self->{connections}->get_widget_value( "Username" )
      , Password            => $self->{connections}->get_widget_value( "Password" )
      , Host                => $self->{connections}->get_widget_value( "Host" )
      , Port                => $self->{connections}->get_widget_value( "Port" )
      , DatabaseType        => $self->{connections}->get_widget_value( "DatabaseType" )
      , ProxyAddress        => $self->{connections}->get_widget_value( "ProxyAddress" )
      , UseProxy            => $self->{connections}->get_widget_value( "UseProxy" )
      , Database            => $self->{connections}->get_widget_value( "Database" )
      , UseBuilder          => $self->{connections}->get_widget_value( "UseBuilder" )
      , Attribute_1         => $self->{connections}->get_widget_value( "Attribute_1" )
      , Attribute_2         => $self->{connections}->get_widget_value( "Attribute_2" )
      , Attribute_3         => $self->{connections}->get_widget_value( "Attribute_3" )
      , Attribute_4         => $self->{connections}->get_widget_value( "Attribute_4" )
      , Attribute_5         => $self->{connections}->get_widget_value( "Attribute_5" )
      , ODBC_driver         => $self->{connections}->get_widget_value( "ODBC_driver" )
    };
    
    return $auth_hash;
    
}

sub on_connections_changed {
    
    my ( $self ) = @_;
    
    if ( $self->{connections}->get_widget_value( 'UseBuilder' ) ) {
        
        my $auth_hash = $self->get_auth_hash;
        
        my $dbh = Database::Connection::generate(
            $self->{globals}
          , $auth_hash
          , 1
        );
        
        my $connection_string   = $dbh->build_connection_string( $auth_hash );
        
        $self->{connections}->set_widget_value( 'ConnectionString', $connection_string );
        
    }
    
    return TRUE;
    
}

sub test_connection {
    
    my $self = shift;
    
    my $auth_hash = {
        Username            => $self->{connections}->get_widget_value( "Username" )
      , Password            => $self->{connections}->get_widget_value( "Password" )
      , Host                => $self->{connections}->get_widget_value( "Host" )
      , Port                => $self->{connections}->get_widget_value( "Port" )
      , DatabaseType        => $self->{connections}->get_widget_value( "DatabaseType" )
      , ConnectionString    => $self->{connections}->get_widget_value( 'ConnectionString' )
      , ProxyAddress        => $self->{connections}->get_widget_value( "ProxyAddress" )
      , UseProxy            => $self->{connections}->get_widget_value( "UseProxy" )
      , Database            => $self->{connections}->get_widget_value( "Database" )
      , Attribute_1         => $self->{connections}->get_widget_value( "Attribute_1" )
      , Attribute_2         => $self->{connections}->get_widget_value( "Attribute_2" )
      , Attribute_3         => $self->{connections}->get_widget_value( "Attribute_3" )
      , Attribute_4         => $self->{connections}->get_widget_value( "Attribute_4" )
      , Attribute_5         => $self->{connections}->get_widget_value( "Attribute_5" )
    };
    
    my $dbh = Database::Connection::generate(
        $self->{globals}
      , $auth_hash
    );
    
    if ( $dbh ) {
        
        $self->dialog(
            {
                title       => "Connection Successful!"
              , type        => "info"
              , text        => "Be proud ... you've connected!"
            }
        );
        
    }
    
}

sub on_DatabaseType_changed {
    
    my $self = shift;
    
    my $auth_hash = $self->get_auth_hash;
    
    if ( ! $auth_hash->{DatabaseType} ) {
        return;
    }
    
    my $dbh = Database::Connection::generate(
        $self->{globals}
      , $auth_hash
      , 1
    );
    
    my $connection_label_map = $dbh->connection_label_map;
    
    foreach my $key ( keys %{$connection_label_map} ) {
        print "$key\n";
        my $value = $connection_label_map->{$key};
        if ( $value ne '' ) {
            $self->{builder}->get_object( $key . '_lbl' )->set_text( $connection_label_map->{$key} );
            $self->{builder}->get_object( $key . '_frame' )->set_visible( 1 );
        } else {
            $self->{builder}->get_object( $key . '_frame' )->set_visible( 0 );
        }
    }

    if ( $dbh->has_odbc_driver ) {


    }

    # For Oracle and DB2, we need the 'Database' field populated
    
    #if ( $db_type eq 'Oracle' || $db_type eq 'DB2' ) {
    #    $self->{builder}->get_object( 'DatabaseFrame' )->set_visible( 1 );
    #    if ( $db_type eq 'Oracle' ) {
    #        $self->{builder}->get_object( 'DatabaseLabel' )->set_text( 'ORATAB Instance' );
    #    } else {
    #        $self->{builder}->get_object( 'DatabaseLabel' )->set_text( 'Database' );
    #    }
    #} else {
    #    $self->{builder}->get_object( 'DatabaseFrame' )->set_visible( 0 );
    #}
    
    # For SQLite, we need a browser for the database path ( Host )
    
    #if ( $db_type eq 'SQLite' ) {
    #    $self->{builder}->get_object( 'Host_IP_Label' )->set_text( 'Database Path' );
    #    $self->{builder}->get_object( 'BrowseForLocation' )->set_visible( 1 );
    #} else {
    #    $self->{builder}->get_object( 'Host_IP_Label' )->set_text( 'Hostname / IP' );
    #    $self->{builder}->get_object( 'BrowseForLocation' )->set_visible( 0 );
    #}
    
}

sub on_BrowseForLocation_clicked {
    
    my $self = shift;
    
    my $path = $self->file_chooser(
        {
            title       => "Select a SQLite database file"
          , type        => "file"
        }
    );
    
    if ( $path ) {
        $self->{builder}->get_object( "Host" )->set_text( $path );
    }
    
}

sub on_Password_Visible_toggled {
    
    my $self = shift;
    
    my $password_widget = $self->{builder}->get_object( 'password' );
    $password_widget->set_visibility( ! $password_widget->get_visibility );
    
}

sub dbConnectByString {
    
    # This function connects to a specified database WITHOUT using a DSN
    #    ( ie the entries in odbc.ini or .odbc.ini )
    
    my ( $self, $string ) = @_;
    
    my $dbh;
    
    eval {
        $dbh = DBI->connect( $string )
            || die( DBI->errstr );
    };
    
    if ( $@ ) {
        
        $self->dialog(
            {
                title   => "Can't connect!",
                type    => "error",
                text    => "Could not connect to database\n" . $@
            }
        );
        
        return 0;
        
    } else {
        
        return $dbh;
        
    }
    
}

sub on_MaskUnmask_clicked {
    
    my $self = shift;
    
    $self->{builder}->get_object( 'Password' )->set_visibility( ! $self->{builder}->get_object( 'Password' )->get_visibility );
    
}

sub on_ODBC_driver_config_clicked {

    my $self = shift;

    my $odbc_config_dialog = $self->open_window(
        'window::odbc_config'
      , $self->{globals}
    );

}

1;
