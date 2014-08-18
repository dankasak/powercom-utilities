package powercom::pvoutput;

# This class implements the PVOutput v2.0 API

use strict;

use LWP::UserAgent;
use Data::Dumper;

use constant    MAX_ERRORS          => 3;

use constant    BASE_URL            => 'http://pvoutput.org/service';
use constant    API_VERSION         => 'r2';

use constant    ADD_OUTPUT_SERVICE  => 'addoutput.jsp';
use constant    ADD_STATUS_SERVICE  => 'addstatus.jsp';
use constant    GET_STATUS_SERVICE  => 'getstatus.jsp';
use constant    SEARCH_SERVICE      => 'search.jsp';


sub new {
    
    my $class   = shift;
    my $api_key = shift || die( 'No api key' );
    my $sys_id  = shift || die( 'No sys id' );
    
    my $self;
    
    $self->{api_key} = $api_key;
    $self->{sys_id}  = $sys_id;
    
    bless $self, $class;
    
    return $self;
    
}

sub add_output {
    
    my ( $self, $data_hash ) = @_;
    
    my $post_data = {
        d       => substr( $data_hash->{reading_date}, 0, 4 )
                 . substr( $data_hash->{reading_date}, 5, 2 )
                 . substr( $data_hash->{reading_date}, 8, 2 )
      , g       => $data_hash->{total_ac_power}
      , pp      => $data_hash->{max_ac_power}
      , cd      => $data_hash->{weather_condition} || 'Not Sure'
    };
    
    return $self->server(
        ADD_OUTPUT_SERVICE
      , $post_data
    );
    
}

sub ping {
    
    my $self = shift;
    
    return $self->server(
        SEARCH_SERVICE
      , {
            q   => '*****'
        }
    );
    
}

sub server {
    
    my $self            = shift;
    my $service_name    = shift || die( 'Missing param service_name' );
    my $post_data       = shift;
    my $options_hash    = shift;
    
    my $done            = 0;
    my $error_count     = 0;
    
    my $return_text;
    
    my $full_url = BASE_URL . '/' . API_VERSION . '/' . $service_name;
    
    while ( ( ! $done ) && $error_count < MAX_ERRORS ) {
        
        my $result;
        
        if ( $post_data ) {
            $result = $self->user_agent->post(
                $full_url
              , $post_data
            ); 
        } else {
            $result = $self->user_agent->post(
                $full_url
            );
        }
        
        $return_text = $result->decoded_content;
        
        if ( ! $result->is_success ) {
            
            warn( "pvoutput upload failed: [$return_text]\n" );
            $error_count ++;
            sleep 10;
            
        } else {
            
            $done = 1;
            
        }
        
    }
    
    return {
        done        => $done
      , return_text => $return_text
    };
    
}

sub user_agent {
    
    my $self = shift;
    
    if ( ! $self->{user_agent} ) {
        
        $self->{user_agent}  = LWP::UserAgent->new();
        $self->{user_agent}->agent( 'PowerCom::pvoutput/0.1' );
        
        $self->{user_agent}->default_header(
            "X-Pvoutput-Apikey"     => $self->{api_key}
          , "X-Pvoutput-SystemId"   => $self->{sys_id}
          , "Content-Type"          => "application/x-www-form-urlencoded"
        );
        
    }
    
    return $self->{user_agent};
    
}

1;
