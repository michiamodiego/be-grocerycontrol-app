package result::value;

use strict; 
use base qw(result::result);

our @ISA = qw(result::result);

sub new {

    my $class = shift;
    my $value = shift;

    if(!defined $value) {
        die("You must define a value");
    }
    
    my $self = {
        value => $value
    };
    
    bless($self, $class);
    
    return $self;

}

1;