package dbutils::ext;

use strict; 
use result::value;
use result::error;


sub getLastInsertedId {

    my $dbh = shift;
    my $query = $dbh->prepare("SELECT LAST_INSERT_ROWID()");

    if(!defined $query || !$query->execute()) {
        return result::error->new("Impossibile recupare l'ultimo id: si è verificato un errore tecnico");
    }

    my $resultset = $query->fetchall_arrayref();

    if(scalar(@{$resultset}) == 0) {
        return result::error->new("Impossibile recupare l'ultimo id");
    }

    return result::value->new($resultset->[0][0]);

}

1;