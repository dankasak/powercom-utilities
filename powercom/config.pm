package powercom::config;

# This class drives the stand-alone config window
# It's not currently in use; I've merged this functionality
# back into the main window

use strict;
use warnings;

use Data::Dumper;
use DateTime;

sub new {
    
    my ( $class, $globals ) = @_;
    
    my $self;
    $self->{globals} = $globals;
    bless $self, $class;
    
    $self->{builder} = Gtk3::Builder->new;
    
    $self->{builder}->add_objects_from_file( "$self->{globals}->{builder_dir}/config.ui", "config" );
    
    $self->{builder}->connect_signals( undef, $self );
    
    $self->{builder}->get_object( "info" )->get_buffer->set_text(
        "PV Output is a website for uploading and comparing your generation statistics.\n"
      . "Create an account at http://www.pvoutput.org/ and enter your details here."
    );
    
#    $self->{builder}->get_object( "viewer" )->maximize;
    
    $self->{builder}->get_object( "APIKey" )->set_text( $self->{globals}->{config_manager}->simpleGet( "APIKey" ) || "" );
    $self->{builder}->get_object( "SYS_ID" )->set_text( $self->{globals}->{config_manager}->simpleGet( "SYS_ID" ) || "" );
    
    $self->{builder}->get_object( "config" )->show;
    
    return $self;
    
}

sub on_PVOutputTestAPI_clicked {
    
    my $self = shift;
    
    my $api_key = $self->{builder}->get_object( "APIKey" )->get_text;
    my $sys_id  = $self->{builder}->get_object( "SYS_ID" )->get_text;
    
    if ( ! $api_key || ! $sys_id ) {
        warn "Need API key and SYS ID"; # TODO: gui
        return;
    }
    
    my $pvoutput = powercom::pvoutput->new(
        $api_key
      , $sys_id
    );
    
    my $response = $pvoutput->ping;
    
    if ( $response->{done} ) {
        powercom::dialog::new(
            {
                type    => 'info'
              , text    => "Test successful"
            }
        );
    } else {
        powercom::dialog::new(
            {
                type    => 'error'
              , text    => "Test failed:\n" . $response->{return_text}
            }
        );
    }
}

sub on_SaveAPIKeys_clicked {
    
    my $self = shift;
    
    $self->{globals}->{config_manager}->simpleSet( "APIKey", $self->{builder}->get_object( "APIKey" )->get_text );
    $self->{globals}->{config_manager}->simpleSet( "SYS_ID", $self->{builder}->get_object( "SYS_ID" )->get_text );
    
}

1;
