#!/usr/bin/env perl

use Mojolicious::Lite -signatures;
use Data::Dumper;
use lib qw(./);
use result::error;
use utils::httpresponse;
use config;
use middleware::common;


post "/login" => sub ($c) {

    my $username = $c->req->json->{username};
    my $password = $c->req->json->{password};

    if(!defined $username || !defined $password) {
        utils::httpresponse::badrequest(
            $c, result::error->new("La richiesta non è valida, username o password vuoti")
        );
        return;
    }

    my $rservice = config::getServiceLocator()->get("authservice");

    if($rservice->error()) {
        utils::httpresponse::interalse($c, result::error->new("Errore durante l'elaborazione della richiesta"));
        return; 
    }

    my $rlogin = $rservice->value()->login($username, $password);

    if($rlogin->error()) {
        utils::httpresponse::unauth($c, $rlogin);
        return;
    }

    my $login = $rlogin->value();

    my $token = $login->{token};
    my $account = $login->{account};

    $c->res->headers->header("x-bgcontrol-token", $token->{token});
    $c->res->headers->header("x-bgcontrol-expiresat", $token->{expiresAt});
    $c->render(json => $account);

};

get '/profile' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{userservice}->getAccountById(
            $context->{principal}->{id}
        )
    );

}, ["userservice"]);

get '/markets' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    utils::httpresponse::valueOrInternalSE(
        $context->{c}, 
        $context->{dependencies}->{marketservice}->getMarketList()
    );

}, ["marketservice"]);

post '/markets' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{marketservice}->createMarket(
            $c->req->json->{name}, 
            $c->req->json->{address}, 
            $c->req->json->{city}, 
            $c->req->json->{postalCode}, 
            $context->{principal}
        )
    );

}, ["marketservice"]);

put '/markets/:id' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{marketservice}->updateMarket(
            $c->param("id"), 
            $c->req->json->{name}, 
            $c->req->json->{address}, 
            $c->req->json->{city}, 
            $c->req->json->{postalCode}, 
            $c->req->json->{version}, 
            $context->{principal}
        )
    );

}, ["marketservice"]);

get '/products' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    utils::httpresponse::valueOrInternalSE(
        $context->{c}, 
        $context->{dependencies}->{productservice}->getProductList()
    );

}, ["productservice"]);

get '/products/:id' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{productservice}->getProductById($c->param("id"))
    );

}, ["productservice"]);

post '/products' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{productservice}->createProduct(
            $c->req->json->{name}, 
            $c->req->json->{description}, 
            $c->req->json->{code}, 
            $c->req->json->{quantity}, 
            $c->req->json->{uom}, 
            $context->{principal}
        )
    );

}, ["productservice"]); 

put '/products/:id' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{productservice}->updateProduct(
            $c->param("id"),
            $c->req->json->{name}, 
            $c->req->json->{description}, 
            $c->req->json->{code}, 
            $c->req->json->{quantity}, 
            $c->req->json->{uom}, 
            $c->req->json->{version}, 
            $context->{principal}
        )
    );

}, ["productservice"]);

post '/markets/:marketid/products/:productid/price-detections' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{statservice}->addPriceDetection(
            $c->param("productid"), 
            $c->param("marketid"), 
            $c->req->json->{price}, 
            $c->req->json->{promo},
            $context->{principal}
        )
    );

}, ["statservice"]);

get '/markets/:marketid/products/:productid/price-detections' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{statservice}->getPriceDetectionList(
            $c->param("productid"), 
            $c->param("marketid")
        )
    );

}, ["statservice"]);

get '/markets/:marketid/products/:productid/price-detections/survey' => middleware::common::createAuthenticatedContext(sub {

    my $context = shift;

    my $c = $context->{c};

    utils::httpresponse::valueOrInternalSE(
        $c, 
        $context->{dependencies}->{statservice}->getSurvey(
            $c->param("productid"), 
            $c->param("marketid")
        )
    );

}, ["statservice"]);

app->start;