package dbutils::txtemplate;

use strict;
use result::result;
use dbutils::transaction;


sub new {

    my $class = shift;
    
    my $self = {
        dbtemplate => shift, 
        tx => dbutils::transaction->new()
    };

    bless($self, $class);

    return $self;

}

sub open {

    my $self = shift;
    my $callback = shift;

    return $self->{dbtemplate}->connect(@_, sub {

        my $dbh = shift;

        $self->{tx}->start($dbh);
        
        my $rcallback = $callback->($dbh);
        
        my $result = $rcallback;

        if(!defined $rcallback) {

            $result = result::error->new("Your callback must define a result, even it is a none");

        }

        if($result->error()) {
            $self->{tx}->setToRollback();
        }

        if($self->{tx}->isToRollback()) {

            $self->{tx}->rollback($dbh);

        } else {

            $self->{tx}->commit($dbh);
            
        }

        return $result;

    });

}

1;