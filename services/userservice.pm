package services::userservice;

use strict;
use Data::Dumper;
use result::value;
use result::error;


sub new {

    my $class = shift;
    my $dbtemplate = shift;

    my $self = {
        dbtemplate => $dbtemplate
    };

    bless($self, $class);
    
    return $self;

}

sub getUserByUsername {

    my $self = shift;
    my $username = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                username, 
                password, 
                email 
            FROM 
                user 
            WHERE 
                username = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($username)) {
            return result::error->new("Impossibile recuperare l'utente per username: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recuperare l'utente per username: nessun utente trovato");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            username => $resultset->[0][1], 
            password => $resultset->[0][2], 
            email => $resultset->[0][3]
        });

    });

}

sub getUserById {

    my $self = shift;
    my $userId = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                username, 
                password, 
                email 
            FROM 
                user 
            WHERE 
                id = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($userId)) {
            return result::error->new("Impossibile recuperare l'utente: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recupeare l'utente: nessun utente trovato");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            username => $resultset->[0][1], 
            password => $resultset->[0][2], 
            email => $resultset->[0][3]
        });

     });

}

sub getAccountById {

    my $self = shift;
    my $id = shift;
    
    my $ruser = $self->getUserById($id);

    if($ruser->error()) {
        return result::error->new("Impossibile recuperare l'account");
    }

    my $account = $ruser->value();

    delete($account->{password});

    return result::value->new($account);

}

1;