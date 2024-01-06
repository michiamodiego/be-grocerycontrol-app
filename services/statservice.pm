package services::statservice;

use strict;
use Data::Dumper;
use result::value;
use result::error;
use result::none;
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

sub getPriceDetection {

    my $self = shift;
    my $id = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                product_id, 
                market_id, 
                price, 
                promo, 
                detected_by, 
                detected_at, 
                version 
            FROM 
                price_detection 
            WHERE 
                id = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($id)) {
            return result::error->new("Impossibile recupare la rilevazione: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recupare la rilevazione: nessuna rilevazione trovata");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            productId => $resultset->[0][1], 
            marketId => $resultset->[0][2], 
            price => $resultset->[0][3], 
            promo => $resultset->[0][4], 
            detectedBy => $resultset->[0][5], 
            detectedAt => $resultset->[0][6], 
            version => $resultset->[0][7]
        });

    });

}

sub addPriceDetection {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $promo = shift;
    my $user = shift;

    if(!defined $price && !defined $promo) {
        return result::error->new("La richiesta non contiene prezzi da aggiornare");
    }

    return $self->{txtemplate}->open(sub {
        
        my $dbh = shift;

        my $statement = q|
            INSERT INTO 
                price_detection (
                    product_id, 
                    market_id, 
                    price, 
                    promo, 
                    detected_by, 
                    detected_at, 
                    version
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        my @params = (
            $productId, 
            $marketId, 
            $price, 
            $promo, 
            $user->{id}, 
            DateTime->now()->epoch(), 
            1
        );

        if(!defined $query || !$query->execute(@params) || $query->rows != 1) {
            return result::error->new("Impossibile aggiungere la rilevazione: si è verificato un errore tecnico");
        }

        my $rlastInsertedId = dbutils::ext::getLastInsertedId($dbh);

        if($rlastInsertedId->error()) {
            return result::error->new("Impossibile aggiungere la rilevazione: si è verificato un errore tecnico");
        }

        my $rpd = $self->getPriceDetection($rlastInsertedId->value());

        my $rupdateProductStats = $self->upsertProductStats($productId, $marketId, $price, $promo, $user);
        my $rupsertPerMarketStats = $self->upsertPerMarketStats($productId, $marketId, $price, $promo, $user);

        if($rupdateProductStats->error() || $rupsertPerMarketStats->error()) {
            return result::error->new("Impossibile aggiungere la statistica di prodotto o per market");
        }
                
        if($rpd->error()) {
            #"Impossibile aggiungere la rilevazione: nessuna rilevazione trovata"
            return result::error->new($rpd->cause());
        }

        return $rpd;

    });

}

sub getProductStat {

    my $self = shift;
    my $name = shift;
    my $productId = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                product_id, 
                market_id, 
                price, 
                iteration, 
                detected_by, 
                detected_at, 
                version 
            FROM 
                product_stat 
            WHERE 
                name = ? AND 
                product_id = ? 
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($name, $productId)) {
            return result::error->new("Impossibile recuperare la statistica ($name): si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recuperare la statistica ($name): nessuna statistica trovata");
        }

        return result::value->new({
            id => $resultset->[0][0], 
            name => $resultset->[0][1], 
            productId => $resultset->[0][2], 
            marketId => $resultset->[0][3], 
            price => $resultset->[0][4], 
            iteration => $resultset->[0][5], 
            detectedBy => $resultset->[0][6], 
            detectedAt => $resultset->[0][7], 
            version => $resultset->[0][8]
        });

    });

}

sub createProductStat {

    my $self = shift;
    my $name = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $iteration = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q|
            INSERT INTO 
                product_stat (
                    name, 
                    product_id, 
                    market_id, 
                    price, 
                    iteration, 
                    detected_by, 
                    detected_at, 
                    version
                ) 
                VALUES 
                    (?, ?, ?, ?, ?, ?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        my @params = (
            $name, 
            $productId, 
            $marketId, 
            $price, 
            $iteration, 
            $user->{id}, 
            DateTime->now()->epoch(), 
            1
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile creare la statistica ($name): si è verificato un errore tecnico");
        }

        my $rstat = $self->getProductStat($name, $productId);

        if($rstat->error()) {
            return result::error->new("Impossibile creare la statistica ($name): statistica non trovata");
        }

        return $rstat;

    });

}

sub updateProductStat {

    my $self = shift;
    my $stat = shift;

    my $statName =  $stat->{"name"};

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q!
            UPDATE 
                product_stat 
            SET 
                market_id = ?, 
                price = ?, 
                iteration = ?, 
                detected_by = ?, 
                detected_at = ?, 
                version = ? 
            WHERE 
                name = ? AND 
                product_id = ? AND 
                version = ?
            !;

        my $query = $dbh->prepare($statement);

        my @params = (
            $stat->{marketId}, 
            $stat->{price}, 
            $stat->{iteration}, 
            $stat->{detectedBy}, 
            $stat->{detectedAt}, 
            $stat->{version} + 1, 
            $statName, 
            $stat->{productId}, 
            $stat->{version}
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile aggiornare la statistica ($statName): si è verificato un errore tecnico");
        }

        my $rupdatedStat = $self->getProductStat($statName, $stat->{productId});

        if($rupdatedStat->error()) {
            return result::error->new("Impossibile aggiornare la statistica ($statName): nessuna statistica trovata");
        }

        return $rupdatedStat;

    });

}

sub getProductStats { 

    my $self = shift;
    my $productId = shift;

    my $rpriceMinStat = $self->getProductStat("PRODUCT_PRICE_MIN", $productId);
    my $rpromoMinStat = $self->getProductStat("PRODUCT_PROMO_MIN", $productId);
    my $rpriceMaxStat = $self->getProductStat("PRODUCT_PRICE_MAX", $productId);
    my $rpromoMaxStat = $self->getProductStat("PRODUCT_PROMO_MAX", $productId);
    my $rpriceMeanStat = $self->getProductStat("PRODUCT_PRICE_MEAN", $productId);
    my $rpromoMeanStat = $self->getProductStat("PRODUCT_PROMO_MEAN", $productId);
    my $rpriceLastStat = $self->getProductStat("PRODUCT_PRICE_LAST", $productId);
    my $rpromoLastStat = $self->getProductStat("PRODUCT_PROMO_LAST", $productId);

    if($rpriceMinStat ->error() || 
        $rpromoMinStat->error() || 
        $rpriceMaxStat->error() || 
        $rpromoMaxStat->error() ||
        $rpriceMeanStat->error() ||
        $rpromoMeanStat->error() ||
        $rpriceLastStat->error() ||
        $rpromoLastStat->error()) {
        return result::error->new("Impossibile recuperare le statistiche di prodotto");
    }

    return result::value->new({
        priceMinStat => $rpriceMinStat->value(), 
        promoMinStat => $rpromoMinStat->value(), 
        priceMaxStat => $rpriceMaxStat->value(), 
        promoMaxStat => $rpromoMaxStat->value(), 
        priceMeanStat => $rpriceMeanStat->value(), 
        promoMeanStat => $rpromoMeanStat->value(), 
        priceLastStat => $rpriceLastStat->value(), 
        promoLastStat => $rpromoLastStat->value()
    });

}

sub getPerMarketStat {

    my $self = shift;
    my $name = shift;
    my $productId = shift; 
    my $marketId = shift; 

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                name, 
                product_id, 
                market_id, 
                price, 
                iteration, 
                detected_by, 
                detected_at, 
                version 
            FROM 
                permarket_stat 
            WHERE 
                name = ? AND 
                product_id = ? AND 
                market_id = ? 
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($name, $productId, $marketId)) {
            return result::error->new("Impossibile recuperare la statistica ($name): si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {
            return result::error->new("Impossibile recuperare la statistica ($name): nessuna statistica trovata"); 
        }

        return result::value->new({
            id => $resultset->[0][0], 
            name => $resultset->[0][1], 
            productId => $resultset->[0][2], 
            marketId => $resultset->[0][3], 
            price => $resultset->[0][4], 
            iteration => $resultset->[0][5], 
            detectedBy => $resultset->[0][6], 
            detectedAt => $resultset->[0][7], 
            version => $resultset->[0][8]
        });

    });

}

sub createPerMarketStat {

    my $self = shift;
    my $name = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $iteration = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q|
            INSERT INTO 
                permarket_stat (
                    name, 
                    product_id, 
                    market_id, 
                    price, 
                    iteration, 
                    detected_by, 
                    detected_at, 
                    version
                ) 
                VALUES 
                    (?, ?, ?, ?, ?, ?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        my @params = (
            $name, 
            $productId, 
            $marketId, 
            $price, 
            $iteration, 
            $user->{id}, 
            DateTime->now()->epoch(), 
            1
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile creare la statistica ($name): si è verificato un errore tecnico");
        }

        my $rstat = $self->getPerMarketStat($name, $productId, $marketId);

        if($rstat->error()) {
            return result::error->new("Impossibile creare la statistica ($name): nessuna statistica trovata");
        }

        return $rstat;

    });

}

sub updatePerMarketStat {

    my $self = shift;
    my $stat = shift;

    my $statName =  $stat->{"name"};

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $statement = q!
            UPDATE 
                permarket_stat 
            SET 
                market_id = ?, 
                price = ?, 
                iteration = ?, 
                detected_by = ?, 
                detected_at = ?, 
                version = ? 
            WHERE 
                name = ? AND 
                product_id = ? AND 
                market_id = ? AND 
                version = ?
            !;

        my $query = $dbh->prepare($statement);

        my @params = (
            $stat->{marketId}, 
            $stat->{price}, 
            $stat->{iteration}, 
            $stat->{detectedBy}, 
            $stat->{detectedAt}, 
            $stat->{version} + 1, 
            $statName, 
            $stat->{productId}, 
            $stat->{marketId}, 
            $stat->{version}
        );

        if(!defined $query || !$query->execute(@params)) {
            return result::error->new("Impossibile aggiornare la statistica ($statName): si è verificato un errore tecnico");
        }

        my $rupdatedStat = $self->getPerMarketStat($statName, $stat->{productId}, $stat->{marketId});

        if($rupdatedStat->error()) {
            return result::error->new("Impossibile aggiornrare la statistica ($statName): nessuna statistica trovata");
        }

        return $rupdatedStat;

    });

}

sub getPerMarketStats { 

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;

    my $rpriceMinStat = $self->getPerMarketStat("PER_MARKET_PRICE_MIN", $productId, $marketId);
    my $rpromoMinStat = $self->getPerMarketStat("PER_MARKET_PROMO_MIN", $productId, $marketId);
    my $rpriceMaxStat = $self->getPerMarketStat("PER_MARKET_PRICE_MAX", $productId, $marketId);
    my $rpromoMaxStat = $self->getPerMarketStat("PER_MARKET_PROMO_MAX", $productId, $marketId);
    my $rpriceMeanStat = $self->getPerMarketStat("PER_MARKET_PRICE_MEAN", $productId, $marketId);
    my $rpromoMeanStat = $self->getPerMarketStat("PER_MARKET_PROMO_MEAN", $productId, $marketId);
    my $rpriceLastStat = $self->getPerMarketStat("PER_MARKET_PRICE_LAST", $productId, $marketId);
    my $rpromoLastStat = $self->getPerMarketStat("PER_MARKET_PROMO_LAST", $productId, $marketId);

    if($rpriceMinStat ->error() || 
        $rpromoMinStat->error() || 
        $rpriceMaxStat->error() || 
        $rpromoMaxStat->error() ||
        $rpriceMeanStat->error() ||
        $rpromoMeanStat->error() ||
        $rpriceLastStat->error() ||
        $rpromoLastStat->error()) {
        return result::error->new("Impossibile recuperare le statistiche per market");
    }

    return result::value->new({
        priceMinStat => $rpriceMinStat->value(), 
        promoMinStat => $rpromoMinStat->value(), 
        priceMaxStat => $rpriceMaxStat->value(), 
        promoMaxStat => $rpromoMaxStat->value(), 
        priceMeanStat => $rpriceMeanStat->value(), 
        promoMeanStat => $rpromoMeanStat->value(), 
        priceLastStat => $rpriceLastStat->value(), 
        promoLastStat => $rpromoLastStat->value()
    });

}

sub upsertProductStats {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $promo = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $results = {};
        
        if(defined $price) {
            $results->{priceMin} = $self->upsertProductPriceMinStat($productId, $marketId, $price, $user);
            $results->{priceMax} = $self->upsertProductPriceMaxStat($productId, $marketId, $price, $user);
            $results->{priceMean} = $self->upsertProductPriceMeanStat($productId, $marketId, $price, $user);
            $results->{priceLast} = $self->upsertProductPriceLastStat($productId, $marketId, $price, $user); 
        }

        if(defined $promo) {
            $results->{promoMin} = $self->upsertProductPromoMinStat($productId, $marketId, $promo, $user);
            $results->{promoMax} = $self->upsertProductPromoMaxStat($productId, $marketId, $promo, $user);
            $results->{promoMean} = $self->upsertProductPromoMeanStat($productId, $marketId, $promo, $user);
            $results->{promoLast} = $self->upsertProductPromoLastStat($productId, $marketId, $promo, $user);
        }

        my $values = {};

        while(my ($key, $value) = each(%$results)) {
            if($value->error()) {
                return result::error->new("Impossibile aggiornare le statistiche di prodotto");
            } else {
                $values->{$key} = $value->value();
            }
        }

        return result::value->new($values);

    });

}

sub upsertProductStatTemplate {

    my $self = shift;
    my $statName = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;
    my $callback = shift; 

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $rstat = $self->getProductStat($statName, $productId);

        if($rstat->error()) {

            my $rcreatedStat = $self->createProductStat($statName, $productId, $marketId, $price, 1, $user);

            if($rcreatedStat->error()) {
                return result::error->new("Impossibile aggiornare la statistica ($statName): impossibile creare la statistica");
            }

            return $rcreatedStat;

        }

        my $stat = $rstat->value();

        my $rcallback = $callback->($dbh, $stat);

        if($rcallback->error()) {
            return $rcallback;
        }

        if(!$rcallback->value()) {
            return $rstat;
        }

        my $rupdatedStat = $self->updateProductStat($stat);

        if($rupdatedStat->error()) {
            return result::error->new("Impossibile aggiornare la statistica ($statName)");
        }

        return $rupdatedStat;

    });

}

sub upsertProductPriceMinStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PRICE_MIN", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;

            if($price >= $prevPrice) {
                return result::value->new(0);
            }

            $stat->{marketId} = $marketId;
            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPromoMinStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PROMO_MIN", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;

            if($promo >= $prevPromo) {
                return result::value->new(0);
            }

            $stat->{marketId} = $marketId;
            $stat->{price} = $promo;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPriceMaxStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PRICE_MAX", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;

            if($price <= $prevPrice) {
                return result::value->new(0);
            }

            $stat->{marketId} = $marketId;
            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPromoMaxStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PROMO_MAX", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;

            if($promo <= $prevPromo) {
                return result::value->new(0);
            }

            $stat->{marketId} = $marketId;
            $stat->{price} = $promo;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPriceMeanStat { 

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PRICE_MEAN", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift;
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;
            my $prevIteration = $stat->{iteration} + 0;
            my $nextIteration = $prevIteration + 1;

            $stat->{marketId} = $marketId;
            $stat->{price} = (($prevIteration*$prevPrice)+$price)/($nextIteration);
            $stat->{iteration} = $nextIteration;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPromoMeanStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PROMO_MEAN", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;
            my $prevIteration = $stat->{iteration} + 0;
            my $nextIteration = $prevIteration + 1;

            $stat->{marketId} = $marketId;
            $stat->{price} = (($prevIteration*$prevPromo)+$promo)/($nextIteration);
            $stat->{iteration} = $nextIteration;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPriceLastStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PRICE_LAST", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            $stat->{marketId} = $marketId;
            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id}; 
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertProductPromoLastStat {

    my $self = shift;
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertProductStatTemplate(
        "PRODUCT_PROMO_LAST", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            $stat->{marketId} = $marketId;
            $stat->{price} = $promo;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }

    );

}

sub upsertPerMarketStats {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $promo = shift;
    my $user = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $results = {};
        
        if(defined $price) {
            $results->{priceMin} = $self->upsertPerMarketPriceMinStat($productId, $marketId, $price, $user);
            $results->{priceMax} = $self->upsertPerMarketPriceMaxStat($productId, $marketId, $price, $user);
            $results->{priceMean} = $self->upsertPerMarketPriceMeanStat($productId, $marketId, $price, $user);
            $results->{priceLast} = $self->upsertPerMarketPriceLastStat($productId, $marketId, $price, $user); 
        }

        if(defined $promo) {
            $results->{promoMin} = $self->upsertPerMarketPromoMinStat($productId, $marketId, $promo, $user);
            $results->{promoMax} = $self->upsertPerMarketPromoMaxStat($productId, $marketId, $promo, $user);
            $results->{promoMean} = $self->upsertPerMarketPromoMeanStat($productId, $marketId, $promo, $user);
            $results->{promoLast} = $self->upsertPerMarketPromoLastStat($productId, $marketId, $promo, $user);
        }

        my $values = {};

        while(my ($key, $value) = each(%$results)) {
            if($value->error()) {
                return result::error->new("Impossibile aggiornare le statistiche di prodotto");
            } else {
                $values->{$key} = $value->value();
            }
        }

        return result::value->new($values);

    });

}

sub upsertPerMarketStatTemplate {

    my $self = shift; 
    my $statName = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;
    my $callback = shift;

    return $self->{txtemplate}->open(sub {

        my $dbh = shift;

        my $rstat = $self->getPerMarketStat($statName, $productId, $marketId);

        if($rstat->error()) {

            my $rcreatedStat = $self->createPerMarketStat($statName, $productId, $marketId, $price, 1, $user);

            if($rcreatedStat->error()) {
                return result::error->new("Impossibile aggiornare la statistica ($statName): impossibile creare la statistica");
            }

            return $rcreatedStat;

        }

        my $stat = $rstat->value();

        my $rcallback = $callback->($dbh, $stat);

        if($rcallback->error()) {
            return $rcallback;
        }

        if(!$rcallback->value()) {
            return $rstat;
        }

        my $rupdatedStat = $self->updatePerMarketStat($stat);

        if($rupdatedStat->error()) {
            return result::error->new("Impossibile aggiornare la statistica ($statName)");
        }
        
        return $rupdatedStat;

    });

}

sub upsertPerMarketPriceMinStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PRICE_MIN", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;

            if($price >= $prevPrice) {
                return result::value->new(0);
            }

            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPromoMinStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PROMO_MIN", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;

            if($promo >= $prevPromo) {
                return result::value->new(0);
            }

            $stat->{price} = $promo;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPromoMaxStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PROMO_MAX", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;

            if($promo <= $prevPromo) {
                return result::value->new(0);
            }

            $stat->{price} = $promo;
            $stat->{detectedBy} = DateTime->now()->epoch();
            $stat->{detectedAt} = $user->{id};

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPriceMaxStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PRICE_MAX", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;

            if($price <= $prevPrice) {
                return result::value->new(0);
            }

            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPriceMeanStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PRICE_MEAN", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPrice = $stat->{price} + 0;
            my $prevIteration = $stat->{iteration} + 0;
            my $nextIteration = $prevIteration + 1;

            $stat->{price} = (($prevIteration*$prevPrice)+$price)/($nextIteration);
            $stat->{iteration} = $nextIteration;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPromoMeanStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PROMO_MEAN", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            my $prevPromo = $stat->{price} + 0;

            my $prevIteration = $stat->{iteration} + 0;
            my $nextIteration = $prevIteration + 1;

            $stat->{price} = (($prevIteration*$prevPromo)+$promo)/($nextIteration);
            $stat->{iteration} = $nextIteration;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPriceLastStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $price = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PRICE_LAST", 
        $productId, 
        $marketId, 
        $price, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            $stat->{price} = $price;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub upsertPerMarketPromoLastStat {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;
    my $promo = shift;
    my $user = shift;

    return $self->upsertPerMarketStatTemplate(
        "PER_MARKET_PROMO_LAST", 
        $productId, 
        $marketId, 
        $promo, 
        $user, 
        sub {

            my $dbh = shift; 
            my $stat = shift; 

            $stat->{price} = $promo;
            $stat->{detectedBy} = $user->{id};
            $stat->{detectedAt} = DateTime->now()->epoch();

            return result::value->new(1);

        }
    );

}

sub getPriceDetectionList {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                product_id, 
                market_id, 
                price, 
                promo, 
                detected_by,  
                detected_at, 
                version 
            FROM 
                price_detection 
            WHERE 
                product_id = ? AND 
                market_id = ? 
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($productId, $marketId)) {
            result::error->new("Impossibile recuperare l'elenco delle rilevazioni: si è verificato un errore tecnico");
        }

        my $priceDetectionList = [];

        while (my ($id, $productId, $marketId, $price, $promo, $detectedBy, $detectedAt, $version) = $query->fetchrow_array) {
            push(@$priceDetectionList, {
                "id" => $id, 
                "productId" => $productId, 
                "marketId" => $marketId, 
                "price" => $price, 
                "promo" => $promo, 
                "detectedBy" => $detectedBy, 
                "detectedAt" => $detectedAt, 
                "version" => $version
            });
        }

        return result::value->new($priceDetectionList);

    });

}

sub getSurvey {

    my $self = shift; 
    my $productId = shift;
    my $marketId = shift;

    my $rproductStats = $self->getProductStats($productId);
    my $rperMarketStats = $self->getPerMarketStats($productId, $marketId);

    if($rproductStats->error() || $rperMarketStats->error()) {
        return result::error->new("Impossibile generare la survey");         
    }

    return result::value->new({
        "productStats" => $rproductStats->value(), 
        "perMarketStats" => $rperMarketStats->value()
    });
    
};

1;