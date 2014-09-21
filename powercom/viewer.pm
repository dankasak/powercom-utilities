package powercom::viewer;

# This class drives the main window, and does
# basically everything apart from interacting
# with PVOutput; that happens in the
# powercom::pvoutput class

use strict;
use warnings;

use Pango;

use Data::Dumper;
use DateTime;

sub new {
    
    my ( $class, $globals ) = @_;
    
    my $self;
    $self->{globals} = $globals;
    bless $self, $class;
    
    $self->{builder} = Gtk3::Builder->new;
    
    $self->{builder}->add_objects_from_file( "$self->{globals}->{builder_dir}/viewer.ui", "viewer" );
    
    $self->{builder}->connect_signals( undef, $self );
    
    $self->{builder}->get_object( "viewer" )->maximize;
    $self->{builder}->get_object( "viewer" )->show;
    
    $self->{progress} = $self->{builder}->get_object( "ProgressBar" );
    
    $self->set_outstanding_stats;
    
    $self->{builder}->get_object( "APIKey" )->set_text( $self->{globals}->{config_manager}->simpleGet( "APIKey" ) || "" );
    $self->{builder}->get_object( "SYS_ID" )->set_text( $self->{globals}->{config_manager}->simpleGet( "SYS_ID" ) || "" );
    
    # We cache thes value for later - the graph uses them
    $self->{globals}->{Panels_Max_Watts} = $self->{globals}->{config_manager}->simpleGet( "Panels_Max_Watts" ) || 2000;
    $self->{builder}->get_object( "Panels_Max_Watts" )->set_text( $self->{globals}->{Panels_Max_Watts} );
    $self->{globals}->{Graph_Min_Hour} = defined $self->{globals}->{config_manager}->simpleGet( "Graph_Min_Hour" ) ? $self->{globals}->{config_manager}->simpleGet( "Graph_Min_Hour" ) : 6;
    $self->{builder}->get_object( "Graph_Min_Hour" )->set_text( $self->{globals}->{Graph_Min_Hour} );
    $self->{globals}->{Graph_Max_Hour} = defined $self->{globals}->{config_manager}->simpleGet( "Graph_Max_Hour" ) ? $self->{globals}->{config_manager}->simpleGet( "Graph_Max_Hour" ) : 23;
    $self->{builder}->get_object( "Graph_Max_Hour" )->set_text( $self->{globals}->{Graph_Max_Hour} );
    
    $self->{daily_summary} = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{db}
          , sql             => {
                                    select      => "*"
                                  , from        => "daily_summary"
                                  , order_by    => "reading_date desc"
                               }
          , fields          => [
                                    {
                                        name        => "id"
                                      , renderer    => "hidden"
                                    }
                                  , {
                                        name        => "date"
                                      , x_absolute  => 80
                                      , read_only   => 1
                                    }
                                  , {
                                        name        => "max heat sink temp"
                                      , x_percent   => 25
                                      , read_only   => 1
                                    }
                                  , {
                                        name        => "max watts"
                                      , x_percent   => 25
                                      , read_only   => 1
                                    }
                                  , {
                                        name        => "total kWh"
                                      , x_percent   => 25
                                      , number      => {
                                                           decimal_places  => 1
                                                       }
                                    }
                                  , {
                                        name        => "weather condition"
                                      , x_percent   => 25
                                    }
                                  , {
                                        name        => "uploaded"
                                      , x_absolute  => 80
                                      , renderer    => "toggle"
                                      , read_only   => 1
                                    }
                                  , {
                                        name        => "upload_status"
                                      , renderer    => "hidden"
                                    }
                               ]
#          , treeview        => $self->{builder}->get_object( "daily_summary_datasheet" )
          , vbox            => $self->{builder}->get_object( "daily_summary_box" ) 
          , on_row_select   => sub { $self->on_daily_summary_select( @_ ) }
        }
    );
    
    $self->{readings} = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{db}
#          , read_only       => 1
          , sql             => {
                                    select          => "reading_datetime, heat_sink_temperature, ac_power / 20, panel_1_voltage, line_current",
#                                    select          => "*"
                                  , from            => "readings"
                                  , where           => "0=1"
                                  , order_by        => "id"
                               }
#          , treeview        => $self->{builder}->get_object( "readings_datasheet" )
          , vbox            => $self->{builder}->get_object( "readings_box" )
          , fields          => [
                                    {
                                        name        => "reading_datetime"
                                      , x_percent   => 20
                                    }
                                  , {
                                        name        => "heat_sink_temperature"
                                      , x_percent   => 20
                                    }
                                  , {
                                        name        => "ac_power"
                                      , x_percent   => 20
                                      , renderer    => "progress"
                                    }
                                  , {
                                        name        => "panel_1_voltage"
                                      , x_percent   => 20
                                    }
                                  , {
                                        name        => "line_current"
                                      , x_percent   => 20
                                    }
                               ]
        }
    );
    
    $self->{builder}->get_object( "pvoutput_info" )->get_buffer->set_text(
        "PV Output is a website for uploading and comparing your generation statistics.\n"
      . "Create an account at http://www.pvoutput.org/ and enter your details here."
    );
    
    Glib::Timeout->add( 6000, sub { $self->on_daily_summary_select } );
    
    return $self;
    
}

sub set_outstanding_stats {
    
    my $self = shift;
    
    my $sth = $self->{globals}->{db}->prepare(
        "select\n"
      . "    substr(reading_datetime, 1, 10) as reading_date\n"
      . "from\n"
      . "    readings left join daily_summary\n"
      . "        on substr(readings.reading_datetime, 1, 10 ) = daily_summary.reading_date\n"
      . "where\n"
      . "    daily_summary.reading_date is null\n"
      . "group by substr(reading_datetime, 1, 10)"
    ) || die( $self->{globals}->{db}->errstr );
    
    $sth->execute()
        || die( $sth->errstr );
    
    while ( my $row = $sth->fetchrow_hashref ) {
        $self->set_stats_for_day( $row->{reading_date} );
    }
    
}

sub set_stats_for_day {
    
    my ( $self, $day ) = @_;
    
    $self->{progress}->set_text( "Summarising outstanding data for [$day] ..." );
    $self->{progress}->pulse;
    Gtk3::main_iteration() while ( Gtk3::events_pending() );
    
    $self->summarise_daily_sth->execute( $day )
        || die( $self->summarise_daily_sth->errstr );
    
    my $row = $self->summarise_daily_sth->fetchrow_hashref;
    
    if ( ! $row ) {
        
        die( "Didn't get a summary row back for day [$day]" );
        
    } else {
        
        if ( $self->check_if_summary_record_exists( $day ) ) {
            
            $self->update_daily_stats_sth->execute(
                $row->{max_heatsink_temperature}
              , $row->{max_ac_power}
              , $row->{total_accumulated_energy}
              , $day
            ) || die( $self->update_daily_stats_sth->errstr );
            
        } else {
            
            $self->insert_daily_stats_sth->execute(
                $row->{max_heatsink_temperature}
              , $row->{max_ac_power}
              , $row->{total_accumulated_energy}
              , $day
            ) || die( $self->insert_daily_stats_sth->errstr );
            
        }
        
    }
    
    $self->{progress}->set_text( "" );
    $self->{progress}->set_fraction( 0 );
    
}

sub check_if_summary_record_exists {
    
    my ( $self, $day ) = @_;
    
    if ( ! $self->{check_if_summary_record_exists_sth} ) {
        
        $self->{check_if_summary_record_exists_sth} = $self->{globals}->{db}->prepare(
            "select\n"
          . "    reading_date\n"
          . "from\n"
          . "    daily_summary\n"
          . "where\n"
          . "    reading_date = ?"
        ) || die( $self->{globals}->{db}->errstr );
        
    }
    
    $self->{check_if_summary_record_exists_sth}->execute( $day )
        || die( $self->{check_if_summary_record_exists_sth}->errstr );
    
    my $row = $self->{check_if_summary_record_exists_sth}->fetchrow_arrayref;
    
    if ( $row ) {
        return 1;
    } else {
        return 0;
    }
    
}

sub summarise_daily_sth {
    
    my ( $self, $day ) = @_;
    
    if ( ! $self->{summarise_daily_sth} ) {
        $self->{summarise_daily_sth} = $self->{globals}->{db}->prepare(
            "select\n"
          . "    max(heat_sink_temperature) as max_heatsink_temperature\n"
          . "  , max(ac_power) as max_ac_power\n"
          . "  , max(accumulated_energy) - min(accumulated_energy) as total_accumulated_energy\n"
          . "from\n"
          . "    readings\n"
          . "where\n"
          . "    substr(reading_datetime, 1, 10) = ?\n"
          . "group by\n"
          . "    substr(reading_datetime, 1, 10 )"
        ) || die( $self->{globals}->{db}->errstr );
        
    }
    
    return $self->{summarise_daily_sth};
    
}

sub insert_daily_stats_sth {
    
    my $self = shift;
    
    if ( ! $self->{insert_daily_stats_sth} ) {
        
        $self->{insert_daily_stats_sth} = $self->{globals}->{db}->prepare(
            "insert into daily_summary(\n"
          . "    max_heat_sink_temperature\n"
          . "  , max_ac_power\n"
          . "  , total_ac_power\n"
          . "  , reading_date\n"
          . "  , uploaded\n"
          . ") values (\n"
          . "    ?\n"
          . "  , ?\n"
          . "  , ?\n"
          . "  , ?\n"
          . "  , 0\n"
          . ")"
        ) || die( $self->{globals}->{db}->errstr );
        
    }
    
    return $self->{insert_daily_stats_sth};
    
}

sub update_daily_stats_sth {
    
    my $self = shift;
    
    if ( ! $self->{update_daily_stats_sth} ) {
        
        $self->{update_daily_stats_sth} = $self->{globals}->{db}->prepare(
            "update daily_summary set\n"
          . "    max_heat_sink_temperature = ?\n"
          . "  , max_ac_power = ?\n"
          . "  , total_ac_power = ?\n"
          . "where\n"
          . "    reading_date = ?"
        ) || die( $self->{globals}->{db}->errstr );
        
    }
    
    return $self->{update_daily_stats_sth};
    
}

sub on_daily_summary_select {
    
    my $self = shift;
    
    my $day = $self->{daily_summary}->get_column_value( "reading_date" );
    
    if ( $self->{reading_stats_day} ne $day ) {
        $self->{readings}->query( "where reading_datetime like '$day%'" );
    }
    
    $self->{reading_stats_day} = $day;
    
    $self->load_stats_for_date( $day );
    
    $self->{progress}->set_text( $self->{daily_summary}->get_column_value( "upload_status" ) || "" );
    
    return 1;
    
}

sub load_stats_for_date {
    
    my ( $self, $date ) = @_;
    
    my $sth = $self->{globals}->{db}->prepare(
        "select\n"
      . "    reading_datetime\n"
      . "  , heat_sink_temperature\n"
      . "  , ac_power\n"
      . "  , accumulated_energy\n"
      . "from\n"
      . "    readings\n"
      . "where\n"
      . "    reading_datetime like '" . $date . "%'"
    ) || die( $self->{globals}->{db}->errstr );
    
    $sth->execute()
        || die( $sth->errstr );
    
    $self->{daily_stats} = $sth->fetchall_hashref( 'reading_datetime' );
    $self->{no_of_readings} = scalar keys %{$self->{daily_stats}};
    
    foreach my $key ( sort keys %{$self->{daily_stats}} ) {
        
        my $value = $self->{daily_stats}->{ $key };
        
        if ( $value->{heat_sink_temperature} > $self->{max_heat_sink_temperature} ) {
            $self->{max_heat_sink_temperature} = $value->{heat_sink_temperature};
        }
        
        if ( $value->{ac_power} > $self->{max_ac_power} ) {
            $self->{max_ac_power} = $value->{ac_power};
        }
        
    }
    
    $self->{max_ac_power} = $self->{globals}->{Panels_Max_Watts};
    
    if ( $self->{drawing_area} ) {
        $self->{drawing_area}->destroy;
    }
    
    $self->{drawing_area} = Gtk3::DrawingArea->new;

    $self->{builder}->get_object( "graph_box" )->pack_start(
        $self->{drawing_area}, 1, 1, 0 );
    
    $self->{drawing_area}->show;
    $self->{drawing_area}->signal_connect( draw => sub { $self->render_graph( @_ ) } );
    
}

sub render_graph {
    
    my ( $self, $widget, $cairo_context ) = @_;
    
    my $surface = $cairo_context->get_target;
    
    # Create a white backing for the graphs
    $cairo_context->set_source_rgb( 0, 0, 0 );
    
    my $total_width  = $widget->get_allocated_width;
    my $total_height = $widget->get_allocated_height;
    
    print "==================================\n";
    print "total height: $total_height\n";
    print "==================================\n";
    
    my $earliest_sec = $self->{globals}->{Graph_Min_Hour} * 3600;
    my $latest_sec   = $self->{globals}->{Graph_Max_Hour} * 3600;
    my $sec_scale    = $total_width / ( $latest_sec - $earliest_sec );
    
    $cairo_context->rectangle( 0, 0, $total_width, $total_height );
    $cairo_context->fill;
    
    # We also want a bottom buffer of 20 for the legend
    my $graph_area_height = $total_height; # - 20;
    
    use constant  NO_OF_GRAPHS  => 2;
    
    my $temperature_y_scale    = $graph_area_height / ( $self->{max_heat_sink_temperature} ) / NO_OF_GRAPHS;
    my $ac_power_y_scale       = $graph_area_height / ( $self->{max_ac_power} ) / NO_OF_GRAPHS;
    
    my $y_segment              = $graph_area_height / NO_OF_GRAPHS;
    
    $cairo_context->set_source_rgb( 0, 255, 168 );
    $cairo_context->set_line_width( 3 );
    $cairo_context->move_to( 0, $graph_area_height );
    
    my $heat_context  = Cairo::Context->create( $surface );
    my $heat_gradient = Cairo::LinearGradient->create( $total_width / 2, $total_height / 2 , $total_width / 2, 0 );

    $heat_gradient->add_color_stop_rgba( 0  , 1,   0, 1  , 1 );
    $heat_gradient->add_color_stop_rgba( 0.5, 1, 0.4, 0.7, 1 );
    $heat_gradient->add_color_stop_rgba( 1  , 1,   0, 0  , 1 );
    
    $heat_context->set_source( $heat_gradient );
    
    $heat_context->set_line_width( 3 );
    $heat_context->move_to( 0, $y_segment * 1 ) ;
    
    print "HEAT BASE: " . $y_segment . "\n";
    
    my $ac_context     = Cairo::Context->create( $surface );
    my $power_gradient = Cairo::LinearGradient->create( $total_width / 2, $total_height, $total_width / 2, $total_height / 1.5 );
    
    $power_gradient->add_color_stop_rgba( 0  , 0, 0, 1, 1 );
    $power_gradient->add_color_stop_rgba( 0.5, 0, 1, 0, 1 );
    $power_gradient->add_color_stop_rgba( 1  , 1, 1, 0, 1 );
    $ac_context->set_source( $power_gradient );
    
    $ac_context->set_line_width( 3 );
    $ac_context->move_to( 0, $y_segment * 2 ) ;
    
    print "POWER BASE: " . $y_segment * 2 . "\n";
    
    my $counter = 0;
    
#    my ( $min_reading_datetime, $max_reading_datetime );
    
    for my $reading_datetime ( sort keys %{$self->{daily_stats}} ) {
        
        # First, figure out the X value of this data
        my ( $hour, $min, $sec );
        
        if ( $reading_datetime =~ /\d{4}-\d{2}-\d{2}\s(\d{2}):(\d{2}):(\d{2})/ ) {
            ( $hour, $min, $sec ) = ( $1, $2, $3 );
        } else {
            die( "Failed to parse datetime: [$reading_datetime]" );
        }
        
        my $secs_past_earliest = ( ( $hour * 3600 ) + ( $min * 60 ) + $sec ) - $earliest_sec;
        
        my $this_x = $secs_past_earliest * $sec_scale;
        
        # For Y values, 0 is the top of the area
        # So the formula for calculating the Y value is:
        #  BASE OF GRAPH - HEIGHT
        
        my $value = $self->{daily_stats}->{ $reading_datetime };
        
        # For the current bar, we just trace our ceiling, and at the end, close it off
        # along the bottom of the graph area
        
        #############
        # temperature
        my $this_y = ( $y_segment * 1 ) - ( $value->{heat_sink_temperature} * $temperature_y_scale );
        if ( $this_y > $total_height ) {
            print "WTF?\n";
            print "TEMP this y: $this_y\n";
        }
        $heat_context->line_to( $this_x, $this_y );
        
        ##########
        # ac power
        $this_y = ( $y_segment * 2 ) - ( $value->{ac_power} * $ac_power_y_scale );
        #print "POWER this y: $this_y\n";
        $ac_context->line_to( $this_x, $this_y );
        
        $counter ++;
        
    }
    
    print "==================================\n";
    
    print "Closing off HEAT graph, to Y level: [" . $y_segment * 1 . "]\n";
    
    $heat_context->line_to( $total_width, $y_segment * 1 );
    $heat_context->line_to( 0, $y_segment * 1 );
    $heat_context->fill;
    
    print "Closing off POWER graph, to Y level: [" . $y_segment * 2 . "]\n";
    
    $ac_context->line_to( $total_width, $y_segment * 2 );
    $ac_context->line_to( 0, $y_segment * 2 );
    $ac_context->fill;
    
    # - - - - - - - - - -
    # done with graphing
    # - - - - - - - - - -
    
    # Now render the X & Y axis labels and partitioning lines
    my $line_context = Cairo::Context->create( $surface );
    $line_context->set_source_rgba( 1, 1, 1, 0.2 );
    $line_context->set_line_width( 3 );
    
    for ( my $hour = $self->{globals}->{Graph_Min_Hour}; $hour <= $self->{globals}->{Graph_Max_Hour}; $hour++ ) {
        
        my $secs_past_earliest = ( $hour * 3600 ) - $earliest_sec;
        my $this_x = $secs_past_earliest * $sec_scale;
        
        # For the text label, the X value we pass into $self->draw_graph_text is where it starts rendering text.
        # We want the text centered around $this_x ... which is different for 1 & 2 digit numbers ...
        my $label_x_offset = $hour < 10 ? -3 : -8;
        
        $self->draw_graph_text( $cairo_context, $hour, 0, $this_x + $label_x_offset, $total_height - 20 );
        
        # white line
#        $cairo_context->set_source_rgb( 255, 255, 255 );
#        $cairo_context->rectangle( $this_x, $total_height, 5, 0 );
#        $cairo_context->fill;

        $line_context->move_to( $this_x, $total_height - 23 );
        $line_context->line_to( $this_x, 0 );
        $line_context->line_to( $this_x + 1, 0);
        $line_context->line_to( $this_x + 1, $total_height - 23 );
        $line_context->line_to( $this_x, $total_height - 23 );
        $line_context->fill;
        
    }
    
    $cairo_context->set_source_rgb( 255, 255, 255 );    
    
    # temp scale
    print "Rendering HEAT axis ticks ...\n";
    
    my $tick_increment = $self->{max_heat_sink_temperature} / 4;
    foreach my $tick_no ( 1, 2, 3, 4 ) {
        
        my $this_tick_value = $tick_no * $tick_increment;
        my $y = ( $y_segment * 1 ) - ( $tick_no * $tick_increment * $temperature_y_scale );
        
        # For the text, the $y that we pass into $self->draw_graph_text
        # is the TOP ( lower value ) that the text can occupy
        my $label_y_offset = -8;
        
        $self->draw_graph_text(
            $cairo_context
          , $tick_no * $tick_increment
          , 0
          , 0
          , $y + $label_y_offset
        );
        
        $line_context->move_to( 30, $y );
        $line_context->line_to( $total_width, $y );
        $line_context->line_to( $total_width, $y - 1 );
        $line_context->line_to( 30, $y - 1 );
        $line_context->line_to( 30, $y );
        $line_context->fill;
        
    }
    
    # kw scale
    print "Rendering POWER axis ticks ...\n";
    
    $tick_increment = $self->{max_ac_power} / 4;
    foreach my $tick_no ( 1, 2, 3, 4 ) {
        
        my $this_tick_value = $tick_no * $tick_increment;
        my $y = ( $y_segment * 2 ) - ( $tick_no * $tick_increment * $ac_power_y_scale );
        
        # For the text, the $y that we pass into $self->draw_graph_text
        # is the TOP ( lower value ) that the text can occupy
        my $label_y_offset = -8;
        
        $self->draw_graph_text(
            $cairo_context
          , $tick_no * $tick_increment
          , 0
          , 0
          , $y + $label_y_offset
        );
        
        $line_context->move_to( 30, $y );
        $line_context->line_to( $total_width, $y );
        $line_context->line_to( $total_width, $y - 1 );
        $line_context->line_to( 30, $y - 1 );
        $line_context->line_to( 30, $y );
        $line_context->fill;
        
    }
    
}

sub draw_graph_text {
    
    my ( $self, $cr, $text, $angle, $x, $y ) = @_;
    
    print "Writing [$text] at x [$x] y [$y]\n";
    
    my $layout = Pango::Cairo::create_layout( $cr );
    $layout->set_text( $text );
    
    my $desc = Pango::FontDescription->from_string( "Sans Bold 10" );
    $layout->set_font_description( $desc );
    
    $cr->save;
    
    $cr->rotate( $angle );
    
    # Inform Pango to re-layout the text with the new transformation
    Pango::Cairo::update_layout( $cr, $layout );
    
    my ( $width, $height ) = $layout->get_size;
    $cr->move_to( $x, $y );
    Pango::Cairo::show_layout( $cr, $layout );
    
    $cr->restore;
    
}

sub on_DailySummary_Apply_clicked {
    
    my $self = shift;
    
    $self->{daily_summary}->apply;
    
}

sub on_UploadAll_clicked {
    
    my $self = shift;
    
    $self->upload;
    
}

sub upload {
    
    my $self        = shift;
    my $optional_id = shift;
    
    my $sql = "select id, reading_date, max_ac_power, total_ac_power * 1000 as total_ac_power from daily_summary";
    
    if ( $optional_id ) {
        $sql .= " where id = ? order by reading_date";
    } else {
        $sql .= " where uploaded = 0 order by reading_date";
    }
    
    my $sth = $self->{globals}->{db}->prepare(
        $sql
    ) || die( $self->{globals}->{db}->errstr );
    
    if ( $optional_id ) {
        $sth->execute( $optional_id )
            || die( $sth->errstr );
    } else {
        $sth->execute()
            || die( $sth->errstr );
    }
    
    my $update_status = $self->{globals}->{db}->prepare(
        "update daily_summary set uploaded = ?, upload_status = ? where id = ?"
    ) || die( $self->{globals}->{db}->errstr );
    
    my $pv_output = powercom::pvoutput->new(
        $self->{globals}->{config_manager}->simpleGet( "APIKey" ) 
      , $self->{globals}->{config_manager}->simpleGet( "SYS_ID" )
    );
    
    while ( my $row = $sth->fetchrow_hashref ) {
        
        $self->{progress}->set_text( "Uploading data for [" . $row->{reading_date} . "] ..." );
        $self->{progress}->pulse;
        
        Gtk3::main_iteration() while ( Gtk3::events_pending() );
        
        my $response = $pv_output->add_output( $row );
        
        if ( $response->{done} ) {
            
            $update_status->execute(
                1
              , $response->{return_text}
              , $row->{id}
            ) || die( $update_status->errstr );
            
        } else {
            
            $update_status->execute(
                0
              , $response->{return_text}
              , $row->{id}
            ) || die( $update_status->errstr );
            
        }
    }
    
    $self->{progress}->set_text( "" );
    $self->{progress}->set_fraction( 0 );
    
    $self->{daily_summary}->query;
    
}

sub on_UploadSelected_clicked {
    
    my $self = shift;
    
    my $id = $self->{daily_summary}->get_column_value( "id" );
    
    $self->upload( $id );
    
}

sub on_RecalculateSelected_clicked {
    
    my $self = shift;
    
    my $day = $self->{daily_summary}->get_column_value( "reading_date" );
    
    $self->set_stats_for_day( $day );
    
    $self->{daily_summary}->query();
    
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

sub on_SaveConfig_clicked {
    
    my $self = shift;
    
    $self->{globals}->{config_manager}->simpleSet( "APIKey", $self->{builder}->get_object( "APIKey" )->get_text );
    $self->{globals}->{config_manager}->simpleSet( "SYS_ID", $self->{builder}->get_object( "SYS_ID" )->get_text );
    $self->{globals}->{Panels_Max_Watts} = $self->{builder}->get_object( "Panels_Max_Watts" )->get_text;
    $self->{globals}->{Graph_Min_Hour} = $self->{builder}->get_object( "Graph_Min_Hour" )->get_text;
    $self->{globals}->{Graph_Max_Hour} = $self->{builder}->get_object( "Graph_Max_Hour" )->get_text;
    $self->{globals}->{config_manager}->simpleSet( "Panels_Max_Watts", $self->{globals}->{Panels_Max_Watts} );
    $self->{globals}->{config_manager}->simpleSet( "Graph_Min_Hour", $self->{globals}->{Graph_Min_Hour} );
    $self->{globals}->{config_manager}->simpleSet( "Graph_Max_Hour", $self->{globals}->{Graph_Max_Hour} );
    
    $self->render_graph;
    
}

sub on_preferences_menu_item_activate {
    
    my $self = shift;
    
    powercom::config->new( $self->{globals} );
    
}

sub on_viewer_destroy {
    
    my $self = shift;
    
    Gtk3->main_quit();
    
}

1;
