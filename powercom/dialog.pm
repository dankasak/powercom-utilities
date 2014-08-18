package powercom::dialog;

use strict;
use POSIX;


use Glib qw ( TRUE FALSE );

sub new {
    
    my $options = shift;
    
    # $options:
    #  - type               - string        [ ]
    #  - title              - string        ( title of dialog )
    #  - parent_window      - gtkwindow     ( parent of dialog ... goes insensitive
    #  - prompt             - string        ( prompt to display to user )
    #  - inputbox           - boolean       ( create an inputbox for input )
    #  - textview           - boolean       ( create a textview for verbose input )
    #  - default            - string        ( a default value )
    
    my $dialog = Gtk3::MessageDialog->new(
        $options->{parent_window},
        [ qw/modal destroy-with-parent/ ],
        $options->{type},
        'GTK_BUTTONS_OK'
    );
    
    $dialog->set_markup( $options->{text} );
        
    $dialog->show_all;

    my $response = $dialog->run;
    
    $dialog->destroy;
    
    return $response;
    
}

1;
