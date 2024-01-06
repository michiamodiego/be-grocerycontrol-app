package result::result;

sub value {

    my $self = shift;
    
    if($self->error()) {
        die("You must first check whether an error occurred");
    }

    return $self->{value};

}

sub error {

    my $self = shift;

    return defined $self->{cause};

}

sub none {

    my $self = shift;
    
    return defined $self->{none} && $self->{none};

}

sub cause {

    my $self = shift;

    if(!$self->error()) {
        die("You must first check whether an error occurred");
    }

    return $self->{cause};
    
}

1;