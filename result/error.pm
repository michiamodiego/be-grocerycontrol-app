package result::error;

use strict; 
use base qw (result::result);

our @ISA = qw(result::result);

sub new {

    my $class = shift;
    my $cause = shift; 
    
    my $self = {
        cause => $cause
    };
    
    bless($self, $class);
    
    return $self;

}

1;