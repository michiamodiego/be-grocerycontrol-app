package services::marketservice;

use strict;
use DateTime;
use result::value;
use result::error;
use dbutils::dbtemplate;
use dbutils::txtemplate;
use dbutils::ext;


sub new {

    my $class = shift;
    my $dbtemplate = shift;
    my $txtemplate = shift;

    my $self = {
        dbtemplate => $dbtemplate, 
        txtemplate => $txtemplate
    };

    bless($self, $class);

    return $self;

}

sub getMarketById {

    my $self = shift;
    my $id = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                address, 
                city, 
                postal_code, 
                inserted_by, 
                inserted_at, 
                updated_by, 
                updated_at, 
                version 
            FROM 
                market 
            WHERE 
                id = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($id)) {
            return result::error->new("Impossibile recupare il market: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recupare il market");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            name => $resultset->[0][1], 
            address => $resultset->[0][2], 
            city => $resultset->[0][3], 
            postalCode => $resultset->[0][4], 
            insertedBy => $resultset->[0][5], 
            insertedAt => $resultset->[0][6], 
            updatedBy => $resultset->[0][7], 
            updatedAt => $resultset->[0][8], 
            version => $resultset->[0][9]
        });

    });

}

sub getMarketList {

    my $self = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                address, 
                city, 
                postal_code, 
                inserted_by, 
                inserted_at, 
                updated_by, 
                updated_at, 
                version 
            FROM 
                market 
            ORDER BY 
                name ASC
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute()) {
            return result::error->new("Impossibile recupare l'elenco dei market: si è verificato un errore tecnico");
        }

        my $marketList = [];

        while (my ($id, $name, $address, $city, $postalCode, $insertedBy, $insertedAt, $updatedBy, $updatedAt, $version) = $query->fetchrow_array) {
            push(@$marketList, {
                "id" => $id, 
                "name" => $name, 
                "address" => $address, 
                "city" => $city, 
                "postalCode" => $postalCode, 
                "insertedBy" => $insertedBy, 
                "insertedAt" => $insertedAt, 
                "updatedBy" => $updatedBy, 
                "updatedAt" => $updatedAt, 
                "version" => $version
            });
        }

        return result::value->new($marketList);

    });

}

sub createMarket {

    my $self = shift;
    my $name = shift;
    my $address = shift;
    my $city = shift;
    my $postalCode = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q|
            INSERT INTO 
                market (
                    name, 
                    address, 
                    city, 
                    postal_code, 
                    inserted_by, 
                    inserted_at, 
                    version
                ) 
            VALUES 
                (?, ?, ?, ?, ?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        my @params = (
            $name, 
            $address, 
            $city, 
            $postalCode, 
            $user->{id},
            DateTime->now()->epoch(),  
            1
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile creare il market: si è verificato un errore tecnico");
        }

        my $rlastInsertedId = dbutils::ext::getLastInsertedId($dbh);

        if($rlastInsertedId->error()) {
            return result::error->new("Impossibile creare il market: si è verificato un errore tecnico");
        }

        my $rmarket = $self->getMarketById($rlastInsertedId->value());

        if($rmarket->error()) {
            return result::error->new("Impossibile creare il market");
        }

        return result::value->new($rmarket->value());

    });

}

sub updateMarket {

    my $self = shift;
    my $id = shift; 
    my $name = shift;
    my $address = shift;
    my $city = shift;
    my $postalCode = shift;
    my $version = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;
        my $setToRollback = shift;

        my $statement = q|
            UPDATE 
                market 
            SET 
                name = ?, 
                address = ?, 
                city = ?, 
                postal_code = ?, 
                updated_by = ?, 
                updated_at = ?, 
                version = ? 
            WHERE 
                id = ? AND 
                version = ?
        |;
        
        my $query = $dbh->prepare($statement);

        my @params = (
            $name, 
            $address, 
            $city, 
            $postalCode, 
            $user->{id}, 
            DateTime->now()->epoch(),  
            $version + 1, 
            $id, 
            $version
        );

        if(!defined $query || !$query->execute(@params) || $query->rows != 1) {
            return result::error->new("Impossibile aggiornare il market: si è verificato un errore tecnico");
        }

        my $rmarket = $self->getMarketById($id);

        if($rmarket->error()) {
            return result::error->new("Impossibile aggiornare il market");
        }

        return result::value->new($rmarket->value());

    });

}

1;