package powercom::viewer;

# This class drives the main window, and does
# basically everything apart from interacting
# with PVOutput; that happens in the
# powercom::pvoutput class

use strict;
use warnings;

use parent 'window';

use Pango;

use Data::Dumper;
use DateTime;
use Color::Rgb;
use Math::Spline;
use DateTime;

use Glib qw | TRUE FALSE |;

use Storable;

use constant PI    => 4 * atan2(1, 1);

sub new {
    
    my ( $class, $globals ) = @_;
    
    my $self;
    $self->{globals} = $globals;
    bless $self, $class;
    
    $self->{builder} = Gtk3::Builder->new;
    
    $self->{builder}->add_objects_from_file( "$self->{globals}->{builder_dir}/viewer.ui", "viewer", "howto_buffer", "adjustment1" );
    
    $self->{builder}->connect_signals( undef, $self );
    
    $self->{builder}->get_object( "viewer" )->maximize;
    $self->{builder}->get_object( "viewer" )->show;
    
    $self->{progress} = $self->{builder}->get_object( "ProgressBar" );
    
    $self->{builder}->get_object( "APIKey" )->set_text( $self->{globals}->{config_manager}->simpleGet( "APIKey" ) || "" );
    $self->{builder}->get_object( "SYS_ID" )->set_text( $self->{globals}->{config_manager}->simpleGet( "SYS_ID" ) || "" );
    
    # We cache thes value for later - the graph uses them
    $self->{globals}->{Panels_Max_Watts} = $self->{globals}->{config_manager}->simpleGet( "Panels_Max_Watts" ) || 2000;
    $self->{builder}->get_object( "Panels_Max_Watts" )->set_text( $self->{globals}->{Panels_Max_Watts} );

    $self->{stack} = $self->{builder}->get_object( "stack" );
    $self->{stack_switcher} = Gtk3::StackSwitcher->new();
    $self->{stack_switcher}->set_stack( $self->{stack} );
    $self->{builder}->get_object( 'HeaderBar' )->pack_start( $self->{stack_switcher} );
    $self->{stack_switcher}->show_all;

#    $self->{globals}->{Graph_Min_Hour} = defined $self->{globals}->{config_manager}->simpleGet( "Graph_Min_Hour" ) ? $self->{globals}->{config_manager}->simpleGet( "Graph_Min_Hour" ) : 6;
#    $self->{builder}->get_object( "Graph_Min_Hour" )->set_text( $self->{globals}->{Graph_Min_Hour} );
#    $self->{globals}->{Graph_Max_Hour} = defined $self->{globals}->{config_manager}->simpleGet( "Graph_Max_Hour" ) ? $self->{globals}->{config_manager}->simpleGet( "Graph_Max_Hour" ) : 23;
#    $self->{builder}->get_object( "Graph_Max_Hour" )->set_text( $self->{globals}->{Graph_Max_Hour} );

    # Set the initial bounds of the graph(s) ... the whole day
    $self->on_ZoomOut_clicked();

    $self->create_daily_summary_datasheet;

    $self->{sources_datasheet} = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{dbh}
        ,   sql             => {
                                  select          => "source, dataset_sql, summary_sql, colour, sort_order, multiplier, cost_per_kwh, null as rendered_colour",
                                , from            => "sources"
                                , order_by        => "source"
                               }
            , vbox            => $self->{builder}->get_object( "sources_box" )
            , auto_tools_box  => 1
            , on_apply        => sub { $self->cache_sources }
            , fields          => [
                {
                      name        => "source"
                    , x_percent   => 20
                }
              , {
                      name        => "dataset_sql"
                    , x_percent   => 25
                }
              , {
                      name        => "summary_sql"
                    , x_percent   => 25
                }
              , {
                    name        => "colour"
                  , renderer    => "hidden"
                }
              , {
                      name        => "sort_order"
                    , x_absolute  => 100
                }
              , {
                      name        => "multiplier"
                    , x_absolute  => 100
                }
              , {
                      name        => "cost per kwh"
                    , x_absolute  => 100
                }
              , {
                      name        => "rendered_colour"
                    , renderer    => "image"
                    , x_percent   => 10
                    , custom_render_functions  => [ sub { $self->colour_cell_renderer( @_ ) } ]
                    , sql_ignore  => 1
                }
            ]
        }
    );

    $self->cache_sources;

    $self->render_source_colours();

    my $picker = Gtk3::ColorButton->new();
    $picker->set_label( 'Choose colour ...' );
    $picker->signal_connect( 'color-set', sub { $self->on_select_colour( @_ ) } );
    $self->{sources_datasheet}->{recordset_tools_box}->pack_start( $picker, TRUE, TRUE, 2 );
    $self->{sources_datasheet}->{recordset_tools_box}->show_all;

    $self->create_source_datasheets;
    
    my $adjustment = $self->{builder}->get_object( "adjustment1" );
    $adjustment->signal_connect( 'value-changed', sub { $self->on_vertical_adjustment( @ _ ) } );
    $adjustment->set_value( $self->{globals}->{Panels_Max_Watts} );
#    $adjustment->set_upper( 20000 );
#    $adjustment->set_step_increment( 100 );
    
    $self->{builder}->get_object( "pvoutput_info" )->get_buffer->set_text(
        "PV Output is a website for uploading and comparing your generation statistics.\n"
      . "Create an account at http://www.pvoutput.org/ and enter your details here."
    );
    
    return $self;

}

sub on_vertical_adjustment {
    
    my ( $self, $widget ) = @_;
    
    $self->{spline_points} = {};
    
    my $value = $widget->get_value();
    
    my $rounded_value = int( $value / 100 ) * 100;
    
    if ( $rounded_value == $self->{globals}->{Panels_Max_Watts} ) {
        return;
    }
    
    $self->{globals}->{Panels_Max_Watts} = $rounded_value;
    $self->{max_ac_power} = $self->{globals}->{Panels_Max_Watts};
    
    foreach my $drawing_area ( @{$self->{drawing_areas}} ) {
        $drawing_area->queue_draw;
    }
    
    $self->{globals}->{config_manager}->simpleSet( "Graph_Max_Hour", $rounded_value );
    
}

sub render_source_colours {

    my $self = shift;

    # TODO: there are some issues here ... I really don't know what they are, especially since we're pre-rendering things ...

    my $model = $self->{sources_datasheet}->{treeview}->get_model;

    my $iter = $model->get_iter_first;

    while ( $iter ) {

        my $source_name   = $model->get( $iter, $self->{sources_datasheet}->column_from_column_name( "source" ) );
        my $colour_string = $model->get( $iter, $self->{sources_datasheet}->column_from_column_name( "colour" ) );

        print "Rendering source colour: [$source_name] - [$colour_string]\n";

        my ( $r, $g, $b );
        my $fillcolour;

        if ( $colour_string =~ /rgb\((.*),(.*),(.*)\)/ ) {
            ( $r, $g, $b ) = ( $1 / 255, $2 / 255, $3 / 255 );
            $fillcolour = $r | $g | $b | 255;
        }

        my $rgba = Gtk3::Gdk::RGBA->new( $r, $g, $b, 1 );

        my $pixbuf = Gtk3::Gdk::Pixbuf->new( 'GDK_COLORSPACE_RGB', 1, 8, 16, 16 );
        $pixbuf->fill( $rgba );

        $self->{rendered_colour_pixbufs}->{ $source_name } = $pixbuf;

        if ( ! $model->iter_next( $iter ) ) {
            last;
        }

    }

}

sub create_daily_summary_datasheet {

    my $self = shift;

    if ( exists $self->{daily_summary} ) {
        $self->{daily_summary}->destroy;
    }

    my $summary_sources = $self->{globals}->{dbh}->select(
        "select * from sources order by ( case when source = 'production' then 0 else 1 end )"
    );

    my $from   = "\nfrom";
    my $select = "select";

    my $fields;
    my $num_of_source = @$summary_sources;

    my $rgb = Color::Rgb->new( rgb_txt => '/usr/share/X11/rgb.txt' );

    foreach my $source ( @{$summary_sources} ) {

        my $rgb_string = $source->{colour};
        my @rgb;

        if ( $rgb_string =~ /rgb\((\d*),(\d*),(\d*)\)/ ) {
            @rgb = ( $1, $2, $3 );
        }

        if ( $source->{source} ne 'production' ) {

            $select .= "\n  , " . $source->{source} . ".watt_hours"
                     . "\n  , round( " . $source->{source} . ".watt_hours::numeric / 1000 * " . ( $source->{cost_per_kwh} ? $source->{cost_per_kwh} : 0 ) . " , 2 )";
            $from .= "\nleft join    " . $source->{summary_sql} . " " . $source->{source} . " on " . $source->{source} . ".reading_date = production.reading_date";

            push
                @{$fields}
              , {
                    name       => $source->{source} . " kWh"
                  , header_markup => "<span color='#" . $rgb->rgb2hex( @rgb ) . "' weight='bold'>" . $source->{source} . " kWh</span>"
                  , x_percent  => 75 / $num_of_source
                  , renderer   => "progress"
                  , custom_render_functions => [ sub { $self->summary_progress_renderer( @_ ) } ]
                }
              , {
                    name       => $source->{source} . " cost"
                  , header_markup => "<span color='#" . $rgb->rgb2hex( @rgb ) . "' weight='bold'>\$</span>"
                  , x_percent  => 25 / $num_of_source
                  , renderer   => "number"
#                  , number     => {
#                        decimal_places   => 2
#                      , null_if_zero     => 1
#                    }
                };

        } else {

            $select .= "\n    production.reading_date"
                     . "\n  , production.watt_hours"
                     . "\n  , round( production.watt_hours::numeric / 1000 * " . ( $source->{cost_per_kwh} ? $source->{cost_per_kwh} : 0 ) . " , 2 )";
            $from .= "\n             " . $source->{summary_sql} . " " . $source->{source};

            push
                @{$fields}
              , {
                    name       => "reading date"
                  , x_absolute => 100
                }
              , {
                    name       => $source->{source} . " kWh"
                  , header_markup => "<span color='#" . $rgb->rgb2hex( @rgb ) . "' weight='bold'>" . $source->{source} . " kWh</span>"
                  , x_percent  => 75 / $num_of_source
                  , renderer   => "progress"
                  , custom_render_functions => [ sub { $self->summary_progress_renderer( @_ ) } ]
                }
              , {
                    name       => $source->{source} . " cost"
                  , header_markup => "<span color='#" . $rgb->rgb2hex( @rgb ) . "' weight='bold'>\$</span>"
                  , x_percent  => 25 / $num_of_source
                  , renderer   => "number"
            };

        }

    }

    my $sql = $select . $from . "\norder by\n    production.reading_date desc";

    print "\n\n$sql\n\n";

    $self->{daily_summary} = Gtk3::Ex::DBI::Datasheet->new(
        {
            dbh             => $self->{globals}->{dbh}
          , sql             => {
                                   pass_through => $sql
            }
          , fields          => $fields
          , vbox            => $self->{builder}->get_object( "daily_summary_box" )
          , on_row_select   => sub { $self->on_daily_summary_select( @_ ) }
          , column_sorting  => 1
          , multi_select    => 1
        }
    );

}

sub summary_progress_renderer {

    my ( $self , $column, $cell, $model, $iter ) = @_;

#    print "column: $cell->{column}\n";

    my $watt_hours = $model->get( $iter, $cell->{column} );

#    print " watt hours: " . $watt_hours . "\n";

    my $watt_hours_percent = $watt_hours / 20000 * 100; # The use of 20000 is pretty arbitrary, but works well for me

    $cell->set( value => $watt_hours_percent );
    $cell->set( text  => ( $watt_hours ? ( $self->comma_separated( $watt_hours / 1000 ) ) : "" ) );

}

sub on_select_colour {

    my ( $self, $picker ) = @_;

    $self->{sources_datasheet}->set_column_value( "colour", $picker->get_rgba->to_string );
    $self->render_source_colours();

}

sub colour_cell_renderer {

    my ( $self, $column, $renderer, $model, $iter ) = @_;

    my $source_name = $model->get( $iter, $self->{sources_datasheet}->column_from_column_name( 'source' ) );

#    print "renderer activated for [$source_name]\n";

    $renderer->set( 'pixbuf' => $self->{rendered_colour_pixbufs}->{ $source_name } );

}

sub get_sources {

    my ( $self ) = @_;

    my $sth = $self->{globals}->{dbh}->prepare(
        "select * from sources order by source "
    ) || die( $self->{globals}->{dbh}->errstr );

    $sth->execute()
        || die( $sth->errstr );

    my $return = $sth->fetchall_arrayref;

    foreach my $row ( @{$return} ) {
        $self->{stat_types}->{ $row->{source} }->{colour} = $row->{colour};
        $self->{stat_types}->{ $row->{source} }->{multiplier} = $row->{multiplier};
    }

    return $return;

}

sub create_source_datasheets {

    my $self = shift;

    my $sth = $self->{globals}->{dbh}->prepare(
        "select * from sources order by source "
    ) || die( $self->{globals}->{dbh}->errstr );

    $sth->execute()
        || die( $sth->errstr );

    $self->{sources_notebook} = $self->{builder}->get_object( 'sources_notebook' );

    while ( my $row = $sth->fetchrow_hashref ) {
        $self->{stat_types}->{ $row->{source} }->{dataset_sql} = $row->{dataset_sql};
        $self->{stat_types}->{ $row->{source} }->{summary_sql} = $row->{summary_sql};
        $self->{stat_types}->{ $row->{source} }->{colour} = $row->{colour};
        $self->{stat_types}->{ $row->{source} }->{multiplier} = $row->{multiplier};
    }


}

sub on_daily_summary_select {
    
    my $self = shift;

    $self->{graph_selections} = [];
    $self->{graph_selection_counter} = -1;

    undef $self->{motion_events_setup};

    foreach my $drawing_area ( @{$self->{drawing_areas}} ) {
        # TODO: disconnect mouse signals? Or does destroying the drawing area automatically destroy the signals?
        $drawing_area->destroy;
    }

    $self->{drawing_areas} = [];

    my @selected_dates = $self->{daily_summary}->get_column_value( "reading_date" );
    @{$self->{selected_dates}} = @selected_dates;

    foreach my $date ( sort @selected_dates ) {
        $self->load_stats_for_date( $date );
    }

    $self->{motion_events_setup} = 1;

#    $self->{progress}->set_text( $self->{daily_summary}->get_column_value( "upload_status" ) || "" );

    return 1;
    
}

sub load_stats_for_date {
    
    my ( $self, $date ) = @_;

    $self->{max_ac_power} = $self->{globals}->{Panels_Max_Watts};

    foreach my $stat_type ( keys %{$self->{stat_types}} ) {

        my $sth = $self->{globals}->{dbh}->prepare(
            "select reading_datetime, watts * " . $self->{stat_types}->{ $stat_type }->{multiplier} ." as watt_hours\n"
          . "from " . $self->{stat_types}->{ $stat_type }->{dataset_sql} . "\n"
          . "where reading_datetime between ?::DATE - interval '1 hour' and ?::DATE + interval '1 day 1 hour'\n"
          . "order by reading_datetime"
        ) || die( $self->{globals}->{dbh}->errstr );

        $sth->execute( $date, $date )
            || die( $sth->errstr );

        $self->{stat_types}->{ $stat_type }->{stats_array_by_date}->{ $date } = $sth->fetchall_arrayref();

    }

    # TODO: disconnect mouse signal?
    undef $self->{motion_events_setups}->{$date};

    my $drawing_area = Gtk3::DrawingArea->new;

    if ( ! $self->{motion_events_setups}->{$date} ) {

        $drawing_area->add_events(0x004|0x100|0x200); # TODO - find constants for these - they're events like 'mouse move'

        $drawing_area->signal_connect( 'motion_notify_event', sub { $self->handle_graph_mouse_move( @_ ) } );
        $drawing_area->signal_connect( 'button_press_event', sub{ $self->handle_graph_button_press( @_ ) } );
        $drawing_area->signal_connect( 'button_release_event', sub{ $self->handle_graph_button_release( @_ ) } );

    }

    $self->{builder}->get_object( "graph_box" )->pack_start( $drawing_area, 1, 1, 0 );

    $drawing_area->show;
    $drawing_area->signal_connect( draw => sub { $self->render_graph( @_, $date ) } );

    push @{$self->{drawing_areas}}, $drawing_area;

}

sub handle_graph_mouse_move {

    my ( $self, $widget, $event ) = @_;

    $self->{mouse_x} = $event->x;
    $self->{mouse_y} = $event->y;

    if ( $self->{in_graph_selection_drag} ) {
        $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{end_x} = $self->{mouse_x};
        $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{end_y} = $self->{mouse_y};
    }

    if ( ! $self->{mouse_event_queued} ) {
        $self->{mouse_event_queued} = 1;
        foreach my $drawing_area ( @{$self->{drawing_areas}} ) {
            $drawing_area->queue_draw;
        }
    }

}

sub handle_graph_button_press {

    my ( $self, $widget, $event ) = @_;

    $self->{graph_selection_counter} ++;

    $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{start_x} = $self->{mouse_x};
    $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{start_y} = $self->{mouse_y};

    $self->{in_graph_selection_drag} = 1;

}

sub handle_graph_button_release {

    my ( $self, $widget, $event ) = @_;

    $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{end_x} = $self->{mouse_x};
    $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{end_y} = $self->{mouse_y};

    $self->{in_graph_selection_drag} = 0;

}

sub cache_sources {

    my $self = shift;

    my $sth = $self->{globals}->{dbh}->prepare(
        "select source from sources order by sort_order"
    ) || die( $self->{globals}->{dbh}->errstr );

    $sth->execute() || die( $sth->errstr );

    $self->{cached_sources} = undef;

    while ( my $sorted_source = $sth->fetchrow_hashref ) {
        push @{$self->{cached_sources}}, $sorted_source;
    }

}

sub render_graph {
    
    my ( $self, $widget, $cairo_context, $date ) = @_;

    # Do NOT do this:
    #my $surface = $cairo_context->get_target;
    
    # Create a white backing for the graphs
    $cairo_context->set_source_rgb( 0, 0, 0 );
    
    my $total_width  = $widget->get_allocated_width;
    my $total_height = $widget->get_allocated_height;

    $self->{globals}->{total_width} = $total_width;

    my $earliest_sec = $self->{globals}->{Graph_Min_Sec};
    my $latest_sec   = $self->{globals}->{Graph_Max_Sec};

    my $sec_scale    = $total_width / ( $latest_sec - $earliest_sec );
    
    $cairo_context->rectangle( 0, 0, $total_width, $total_height );
    $cairo_context->fill;
    
    # We also want a bottom buffer of 20 for the legend
    my $graph_area_height = $total_height; # - 20;
    
    use constant  NO_OF_GRAPHS  => 1;
    use constant  GRAPH_NO      => 1;

    my $ac_power_y_scale       = $graph_area_height / ( $self->{max_ac_power} ) / NO_OF_GRAPHS;
    
    my $y_segment              = $graph_area_height / NO_OF_GRAPHS;
    
    $cairo_context->set_source_rgb( 0, 255, 168 );
    $cairo_context->set_line_width( 1 );
    $cairo_context->move_to( 0, $graph_area_height );

    foreach my $sorted_source ( @{$self->{cached_sources}} ) {
        $self->render_graph_series( $widget, $sorted_source->{source}, $cairo_context, $date );
    }

    # - - - - - - - - - -
    # done with graphing
    # - - - - - - - - - -
    
    # Now render the X & Y axis labels and partitioning lines
    $cairo_context->set_source_rgba( 1, 1, 1, 0.4 );
    $cairo_context->set_line_width( 1 );

    my $min_hour = int( $earliest_sec / 60 / 60 );
    my $max_hour = int( $latest_sec / 60 / 60 );

    for ( my $hour = $min_hour; $hour <= $max_hour; $hour++ ) {

        my $date_selection_count = scalar( @{$self->{selected_dates}} );

        if ( $date_selection_count > 6 ) {
            if ( $hour != 0 ) {
                next;
            }
        } elsif ( $date_selection_count > 2 ) {
            if  ( $hour % 6 != 0 ) {
                next;
            }
        }

        my $secs_past_earliest = ( $hour * 3600 ) - $earliest_sec;
        my $this_x = $secs_past_earliest * $sec_scale;
        
        # For the text label, the X value we pass into $self->draw_graph_text is where it starts rendering text.
        # We want the text centered around $this_x ... which is different for 1 & 2 digit numbers ...
        my $label_x_offset = $hour < 10 ? -3 : -8;
        
        $self->draw_graph_text( $cairo_context, ( $hour == 24 ? 0 : $hour ), 0, $this_x + $label_x_offset, $total_height - 20 );

        $cairo_context->move_to( $this_x, $total_height - 23 );
        $cairo_context->line_to( $this_x, 0 );
        $cairo_context->line_to( $this_x + 1, 0);
        $cairo_context->line_to( $this_x + 1, $total_height - 23 );
        $cairo_context->line_to( $this_x, $total_height - 23 );
        $cairo_context->fill;
        
    }
    
    # kw scale
    
    my $tick_increment = $self->{max_ac_power} / 4;

    foreach my $tick_no ( 1 , 2 , 3 , 4 ) {

        my $y = ( $y_segment * GRAPH_NO ) - ( $tick_no * $tick_increment * $ac_power_y_scale );

        # For the text, the $y that we pass into $self->draw_graph_text
        # is the TOP ( lower value ) that the text can occupy
        my $label_y_offset = - 8;

        my $selected_dates = $self->{selected_dates};

        my $horizontal_x;

        if ( $date eq $$selected_dates[$#$selected_dates] ) {
            $horizontal_x = 30;
            $self->draw_graph_text(
                $cairo_context
              , $tick_no * $tick_increment
              , 0
              , 0
              , $y + $label_y_offset
            );
        } else {
            $horizontal_x = 0;
        }

        $cairo_context->move_to( $horizontal_x , $y );
        $cairo_context->line_to( $total_width , $y );
        $cairo_context->line_to( $total_width , $y - 1 );
        $cairo_context->line_to( $horizontal_x , $y - 1 );
        $cairo_context->line_to( $horizontal_x , $y );
        $cairo_context->fill;

    }

    if ( $self->{mouse_x} ) {

        $cairo_context->move_to( $self->{mouse_x}, 0 );
        $cairo_context->line_to( $self->{mouse_x}, $total_height - 23 );
        $cairo_context->stroke;

        $cairo_context->move_to( 0, $self->{mouse_y} );
        $cairo_context->line_to( $total_width, $self->{mouse_y} );
        $cairo_context->stroke;

        # pointer time - calculate where on the x axis ( time ) the pointer is at
        my ( $pointer_hour , $pointer_minutes ) = $self->secs_to_time( $self->pointer_x_to_seconds( $self->{mouse_x} ) );

        $self->draw_graph_text(
            $cairo_context
          , $pointer_hour . ":" . sprintf( "%02d", $pointer_minutes )
          , 0
          , ( $pointer_hour < 12 ? $self->{mouse_x} + 10 : $self->{mouse_x} - 50 )
          , $total_height - 50
        );

        # pointer watts - as above, but for the y axis ( watts )
        my $pointer_y_fraction = ( $total_height - $self->{mouse_y} ) / $total_height;
        my $pointer_watts      = int( $self->{max_ac_power} * $pointer_y_fraction );

        $self->draw_graph_text(
            $cairo_context
          , $pointer_watts
          , 0
          , 50
          , $self->{mouse_y}
        );

        $self->{mouse_event_queued} = 0;

    }

    $cairo_context->set_source_rgba( 1, 1, 1, 0.2 );
    $cairo_context->set_line_width( 3 );

    foreach my $selection ( @{$self->{graph_selections}} ) {

        $cairo_context->move_to( $selection->{start_x}, 0 );
        $cairo_context->line_to( $selection->{start_x}, $y_segment * GRAPH_NO  );
        $cairo_context->line_to( $selection->{end_x}, $y_segment * GRAPH_NO  ); # undef
        $cairo_context->line_to( $selection->{end_x}, 0  ); # undef
        $cairo_context->line_to( $selection->{start_x}, 0  );

        $cairo_context->fill;

    }

    # Circle around pointer location
    if ( defined $self->{mouse_x} ) {

        $cairo_context->set_source_rgba( 1, 1, 0, 0.2 );
        $cairo_context->set_line_width( 2 );
        $cairo_context->move_to( $self->{mouse_x} , $self->{mouse_y} );
        $cairo_context->arc( $self->{mouse_x} , $self->{mouse_y} , 7 , 0 , 2 * PI );
        $cairo_context->fill;

    }


}

sub on_ZoomSelected_clicked {

    my $self = shift;

    # Need to calc *both*, then set, otherwise the 2nd point_x_to_seconds() call uses an incorrect start position
    my $min = $self->pointer_x_to_seconds(
        $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{start_x}
    );

    my $max = $self->pointer_x_to_seconds(
        $self->{graph_selections}->[ $self->{graph_selection_counter} ]->{end_x}
    );

    $self->{globals}->{Graph_Min_Sec} = $min;
    $self->{globals}->{Graph_Max_Sec} = $max;

    # Knock out our cached spline points
    $self->{spline_points} = {};

    $self->clear_selections();

}

sub on_ZoomOut_clicked {

    my $self = shift;

    $self->{globals}->{Graph_Min_Sec} = 0;
    $self->{globals}->{Graph_Max_Sec} = 24 * 60 * 60;

    # Knock out our cached spline points
    $self->{spline_points} = {};

    $self->clear_selections();

}

sub clear_selections {

    my $self = shift;

    $self->{graph_selections} = [];
    $self->{graph_selection_counter} = -1;

    foreach my $drawing_area ( @{$self->{drawing_areas}} ) {
        $drawing_area->queue_draw;
    }

}

sub pointer_x_to_seconds {

    my ( $self , $x ) = @_;

    my $pointer_x_fraction = 1 - ( ( $self->{globals}->{total_width} - $x ) / $self->{globals}->{total_width} );

    my $pointer_secs_offset = ( $self->{globals}->{Graph_Max_Sec} - $self->{globals}->{Graph_Min_Sec} ) * $pointer_x_fraction;
    my $pointer_secs = $self->{globals}->{Graph_Min_Sec} + $pointer_secs_offset;

    return $pointer_secs;

}

sub secs_to_time {

    my ( $self , $secs ) = @_;

    my $pointer_hour = int( $secs / 60 / 60 );
    my $seconds_remainder = $secs - ( $pointer_hour * 60 * 60 );
    my $pointer_minutes = int ( $seconds_remainder / 60 );

    return ( $pointer_hour , $pointer_minutes );

}

sub render_graph_series {

    my ( $self, $widget, $source, $cairo_context, $date ) = @_;

    my $total_width  = $widget->get_allocated_width;
    my $total_height = $widget->get_allocated_height;

    my $earliest_sec        = $self->{globals}->{Graph_Min_Sec};
    my $latest_sec          = $self->{globals}->{Graph_Max_Sec};

    my $sec_scale           = $total_width / ( $latest_sec - $earliest_sec );

    # We also want a bottom buffer of 20 for the legend
    my $graph_area_height = $total_height; # - 20;

    use constant  NO_OF_GRAPHS  => 1;
    use constant  GRAPH_NO      => 1;

    my $this_stat_y_scale               = $graph_area_height / ( $self->{max_ac_power} ) / NO_OF_GRAPHS;

    my $y_segment                       = $graph_area_height / NO_OF_GRAPHS;

    my $this_stat_gradient  = Cairo::LinearGradient->create( $total_width, $total_height, $total_width, $total_height );

    my $colour_string       = $self->{stat_types}->{ $source }->{colour};
    my ( $red, $green, $blue, $red_highlight, $green_highlight, $blue_highlight );

    if ( $colour_string =~ /rgb\((.*),(.*),(.*)\)/ ) {

        my ( $red_str , $green_str , $blue_str ) = ( $1 , $2 , $3 );

        # Note that the RGB values we get here ( 0 to 255 ) are NOT what Cairo
        # wants to deal with. Cairo instead uses ( 0 to 1 ) because consistency is for losers

        # Calculate highlight colours
        my $highlight_multiplier = 0.2;

        $red_highlight   = ( $red_str   + ( $highlight_multiplier * ( 255 - $red_str   ) ) ) / 255;
        $green_highlight = ( $green_str + ( $highlight_multiplier * ( 255 - $green_str ) ) ) / 255;
        $blue_highlight  = ( $blue_str  + ( $highlight_multiplier * ( 255 - $blue_str   ) ) ) / 255;

        ( $red, $green, $blue ) = ( $red_str / 255, $green_str / 255, $blue_str / 255 );

    } else {

        warn( "Failed to parse colour string: $colour_string" );

    }

    $this_stat_gradient->add_color_stop_rgba( 0  , 0.0, 0.0, 0.0, 0.7 );
    $this_stat_gradient->add_color_stop_rgba( 1  , $red, $green, $blue, 0.7 );

    # First we loop over each reading, and build a list of x & y co-ordinates that represent the *average* value for each reading
    my ( @x_coords , @y_coords );

    my $no_of_readings = @{ $self->{stat_types}->{ $source }->{stats_array_by_date}->{ $date } };

    my ( $last_x_width , $this_x );

    my $base_y_value = ( $y_segment * GRAPH_NO );

    # NOTE: When we create more than 2 DrawingAreas, I'm seeing minor ( ie 1 ) pixel differences
    # in the total width between render() calls. Recalculating the bezier curves is expensive, so
    # we only do it if there is a difference of > 1 pixel ...

    if ( abs( $self->{last_graph_width} - $total_width ) > 2
      || abs( $self->{last_graph_height} - $total_height ) > 2
      || ! $self->{spline_points}->{ $source }->{ $date }
    ) {

        if ( abs( $self->{last_graph_width} - $total_width ) > 2
          || abs( $self->{last_graph_height} - $total_height ) > 2
        ) {
            # If we've resized, clear out all the calculated points, or only the 1st set will get regenerated
            $self->{spline_points} = {};
        }

        my $last_y;

        # Need to calculate new spline points ...
        foreach my $i ( 0 .. $no_of_readings - 1 ) {

            my $this_reading = $self->{stat_types}->{ $source }->{stats_array_by_date}->{ $date }->[ $i ];

            # First, figure out the *left* *edge* X value of this data.
            # Each figure is an average over time ...

            my $left_secs_past_earliest = $self->time_to_secs( $date, $this_reading->[0] ) - $self->{globals}->{Graph_Min_Sec};

            my $this_x_left  = $left_secs_past_earliest * $sec_scale;
            my $this_x_right;

            # Now the right edge
            if ( $i != $no_of_readings - 1 ) {
                # If we're not the last reading of the day, get the next reading
                my $next_reading = $self->{stat_types}->{ $source }->{stats_array_by_date}->{ $date }->[ $i + 1 ];
                my $right_secs_past_earliest = $self->time_to_secs( $date, $next_reading->[0] ) - $self->{globals}->{Graph_Min_Sec};
                $this_x_right = $right_secs_past_earliest * $sec_scale;
                $last_x_width = $this_x_right - $this_x_left;
            } else {
                # If we are the last reading of the day, use the width of the previous reading
                $this_x_right = $this_x_left + $last_x_width;
            }

            # Finally, the middle point between the 2 edges
            $this_x = ( $this_x_right + $this_x_left ) / 2;

            my $value = $this_reading->[1];

            # For Y values, 0 is the top of the area
            # So the formula for calculating the Y value is:
            #  BASE OF GRAPH - HEIGHT

            my $this_y = $base_y_value - ( $value * $this_stat_y_scale );

            # Check if this value is within our range ( ie when zooming )
#            if ( $this_x < 0 || $this_x > $total_width
#            ) {
#                $last_y = $this_y;
#                next;
#            }
#
#            if ( ! defined $last_y && $this_y != $base_y_value ) {
#
#                # If we're on the *first* reading ( ! defined $last_y ), and it's *not* a baseline reading,
#                # then inject one, just before ( x axis ) this reading
#                push @x_coords, $this_x - 1;
#                push @y_coords, $base_y_value;
#                $last_y = $this_y;
#
#            }

            push @x_coords, $this_x;
            push @y_coords, $this_y;

            if ( $i == $no_of_readings - 1 ) {

                # If we are the last reading of the day, push another point, touching the baseline

                $this_x = $this_x + ( $this_x_right - $this_x_left );
                push @x_coords, $this_x + 1;
                push @y_coords, $base_y_value;
            }

        }

        my $spline = Math::Spline->new( \@x_coords , \@y_coords );

        $self->{spline_points}->{ $source }->{ $date } = [];

        my $first_x = $x_coords[0];
        my $last_x = $x_coords[$#x_coords];

        if ( @x_coords && @y_coords ) {
#            my $loop_start = max( $first_x , ( $self->{globals}->{Graph_Min_Sec} * $sec_scale ) );
#            my $loop_end   = min( $last_x , ( $self->{globals}->{Graph_Max_Sec} * $sec_scale ) );
#            foreach my $i ( $loop_start .. $loop_end ) {
            foreach my $i ( $first_x .. $last_x ) {
                push @{$self->{spline_points}->{ $source }->{ $date }} , $i , $spline->evaluate($i);
            }
        }

        $self->{last_graph_width}  = $total_width;
        $self->{last_graph_height} = $total_height;

    }

    foreach my $pass ( qw | regular highlight | ) {

        if ( $pass eq 'regular' ) {
            $cairo_context->set_source( $this_stat_gradient );
        } else {
            $cairo_context->set_source_rgba( $red_highlight, $green_highlight, $blue_highlight, 1 );
        }

        $cairo_context->move_to( 0 , $base_y_value );

        my @points = @{ $self->{spline_points}->{ $source }->{ $date } };

        my ( $x , $y , $first_x , $last_x );

        $first_x = $self->{spline_points}->{ $source }->{ $date }->[0];
        $last_x  = $self->{spline_points}->{ $source }->{ $date }->[-2];

        while ( ( $x , $y ) = splice( @points, 0, 2 ) ) {
            $cairo_context->line_to( $x, $y );
        }

        {
            no warnings 'uninitialized';
            $cairo_context->line_to( $last_x , $base_y_value );
            $cairo_context->line_to( $first_x , $base_y_value );
        }

        if ( $pass eq 'regular' ) {
            $cairo_context->line_to( $first_x , $base_y_value );
            $cairo_context->fill;
        } else {
            $cairo_context->stroke;
        }

    }

}

sub time_to_secs {

    my ( $self , $date , $time ) = @_;

    my ( $year , $month , $day , $hour , $min , $sec );

    if ( $time =~ /(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})/ ) {
        ( $year , $month, $day , $hour , $min , $sec ) = ( $1 , $2 , $3 , $4 , $5 , $6 );
    } else {
        die( "Failed to parse datetime: [ $time ]" );
    }

    my $datetime = DateTime->new(
        year       => $year
      , month      => $month
      , day        => $day
      , hour       => $hour
      , minute     => $min
      , second     => $sec
    );

    my $this_epoch = $datetime->epoch();

    if ( $date =~ /(\d{4})-(\d{2})-(\d{2})/ ) {
        ( $year , $month , $day ) = ( $1 , $2 , $3 );
    }

    $datetime  = DateTime->new(
        year       => $year
      , month      => $month
      , day        => $day
      , hour       => 0
      , minute     => 0
      , second     => 0
    );

    my $graph_epoch = $datetime->epoch();

#    my $secs_diff = $this_epoch - ( $graph_epoch + $self->{globals}->{Graph_Min_Sec} );
    my $secs_diff = $this_epoch - $graph_epoch;

    return $secs_diff;

}

sub draw_graph_text {
    
    my ( $self, $cr, $text, $angle, $x, $y ) = @_;
    
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

#    print "saving config\n";
    $self->{globals}->{config_manager}->simpleSet( "APIKey", $self->{builder}->get_object( "APIKey" )->get_text );
    $self->{globals}->{config_manager}->simpleSet( "SYS_ID", $self->{builder}->get_object( "SYS_ID" )->get_text );
    $self->{globals}->{Panels_Max_Watts} = $self->{builder}->get_object( "Panels_Max_Watts" )->get_text;
    $self->{globals}->{Graph_Min_Hour} = $self->{builder}->get_object( "Graph_Min_Hour" )->get_text;
    $self->{globals}->{Graph_Max_Hour} = $self->{builder}->get_object( "Graph_Max_Hour" )->get_text;
    $self->{globals}->{config_manager}->simpleSet( "Panels_Max_Watts", $self->{globals}->{Panels_Max_Watts} );
    $self->{globals}->{config_manager}->simpleSet( "Graph_Min_Hour", $self->{globals}->{Graph_Min_Hour} );
    $self->{globals}->{config_manager}->simpleSet( "Graph_Max_Hour", $self->{globals}->{Graph_Max_Hour} );
#    print "saved config\n";
    $self->render_graph;
    
}

sub on_preferences_menu_item_activate {
    
    my $self = shift;
    
    powercom::config->new( $self->{globals} );
    
}

sub comma_separated {

    my ( $self, $number ) = @_;

    $number =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;

    return $number;

}

sub on_DB_Config_clicked {

    my $self = shift;

    $self->open_window( 'powercom::configuration', $self->{globals} );

}

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

sub on_viewer_destroy {
    
    my $self = shift;

    $self->close_window();
    
}

1;
