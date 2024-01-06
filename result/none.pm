package result::none;

use strict; 
use base qw(result::result);

our @ISA = qw(result::result);

sub new {

    my $class = shift;
    
    my $self = {
        none => 1
    };

    bless($self, $class);
    
    return $self;

}

1;