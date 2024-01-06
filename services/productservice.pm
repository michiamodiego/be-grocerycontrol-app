package services::productservice;

use strict;
use DateTime;
use result::value;
use result::error;
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

sub getProductById {

    my $self = shift;
    my $id = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                description, 
                code, 
                quantity, 
                uom, 
                inserted_by, 
                inserted_at, 
                updated_by, 
                updated_at, 
                version 
            FROM 
                product  
            WHERE 
                id = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($id)) {
            return result::error->new("Impossibile recupare il prodotto: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recupare il prodotto");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            name => $resultset->[0][1], 
            description => $resultset->[0][2], 
            code => $resultset->[0][3], 
            quantity => $resultset->[0][4], 
            uom => $resultset->[0][5], 
            insertedBy => $resultset->[0][6], 
            insertedAt => $resultset->[0][7], 
            updatedBy => $resultset->[0][8], 
            updatedAt => $resultset->[0][9], 
            version => $resultset->[0][10]
        });

    });

}

sub getProductList {

    my $self = shift;
    my $id = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                description, 
                code, 
                quantity, 
                uom, 
                inserted_by, 
                inserted_at, 
                updated_by, 
                updated_at, 
                version 
            FROM 
                product  
            ORDER BY 
                name ASC
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute()) {
            return result::error->new("Impossibile recupare il prodotto: si è verificato un errore tecnico");
        }

        my $productList = [];

        while (my ($id, $name, $description, $code, $quantity, $uom, $insertedBy, $insertedAt, $updatedBy, $updatedAt, $version) = $query->fetchrow_array) {
            push(@$productList, {
                "id" => $id, 
                "name" => $name, 
                "description" => $description, 
                "code" => $code, 
                "quantity" => $quantity, 
                "uom" => $uom, 
                "insertedBy" => $insertedBy, 
                "insertedAt" => $insertedAt, 
                "updatedBy" => $updatedBy, 
                "updatedAt" => $updatedAt, 
                "version" => $version
            });
        }

        return result::value->new($productList);

    });

}

sub createProduct {

    my $self = shift;
    my $name = shift;
    my $description = shift;
    my $code = shift;
    my $quantity = shift;
    my $uom = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;
        my $setToRollback = shift;

        my $statement = q|
            INSERT INTO 
                product (
                    name, 
                    description, 
                    code, 
                    quantity, 
                    uom, 
                    inserted_by, 
                    inserted_at, 
                    version
                ) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        my @params = (
            $name, 
            $description, 
            $code, 
            $quantity, 
            $uom, 
            $user->{id}, 
            DateTime->now()->epoch(), 
            1
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile creare il prodotto: si è verificato un errore tecnico");
        }

        my $rlastInsertedId = dbutils::ext::getLastInsertedId($dbh);

        if($rlastInsertedId->error()) {
            return result::error->new("Impossibile creare il prodotto: ultimo id non trovato");
        }

        my $rproduct = $self->getProductById($rlastInsertedId->value());

        if($rproduct->error()) {
            return result::error->new("Impossibile creare il prodotto: nessun prodotto trovato");
        }

        return result::value->new($rproduct->value());

    });

}

sub updateProduct {

    my $self = shift;
    my $id = shift;
    my $name = shift;
    my $description = shift;
    my $code = shift;
    my $quantity = shift;
    my $uom = shift;
    my $version = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q|
            UPDATE product SET 
                name = ?, 
                description = ?, 
                code = ?, 
                quantity = ?, 
                uom = ?, 
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
            $description, 
            $code, 
            $quantity, 
            $uom, 
            $user->{id}, 
            DateTime->now()->epoch(), 
            $version + 1, 
            $id,  
            $version
        );

        if(!defined $query || !$query->execute(@params) || $query->rows != 1) {
            return result::error->new("Impossibile aggiornare il prodotto: si è verificato un errore tecnico");
        }

        my $rproduct = $self->getProductById($id);

        if($rproduct->error()) {
            return result::error->new("Impossibile aggiornare il prodotto");
        }

        return $rproduct;

    });
    
}

1;