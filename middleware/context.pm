package middleware::context;

sub new {

    my $class = shift;

    my $self = {};

    bless($self, $class);

    return $self;
    
}

1;