package dbutils::transaction;

use strict;


sub new {

    my $class = shift;

    my $self = {
        ref => 0, 
        toRollback => 0, 
        started => 0
    };

    bless($self, $class);

    return $self;

}

sub started {

    my $self = shift;

    return $self->{started};

}

sub start {

    my $self = shift;
    my $dbh = shift;

    if(!$self->started()) {
        
        $self->{started} = 1;

        my $query = $dbh->prepare("BEGIN TRANSACTION");
        
        $query->execute();
    
    }

    $self->up();

}

sub rollback {

    my $self = shift;
    my $dbh = shift;

    $self->down();

    if($self->completed()) {

        my $query = $dbh->prepare("ROLLBACK");
        $query->execute();

    }

}

sub commit {

    my $self = shift;
    my $dbh = shift;

    $self->down();

    if($self->completed()) {

        my $query = $dbh->prepare("COMMIT");
        $query->execute();

    }

}

sub completed {

    my $self = shift;

    return $self->{started} && $self->ref() == 0;

}

sub setToRollback {

    my $self = shift;

    $self->{toRollback} = 1;

}

sub isToRollback {

    my $self = shift;

    return $self->{toRollback};

}

sub up {

    my $self = shift;

    $self->{ref}++;

}

sub down {

    my $self = shift;

    $self->{ref}--;

}

sub ref {

    my $self = shift;

    return $self->{ref};
    
}

1;