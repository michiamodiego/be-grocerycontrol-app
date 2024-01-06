package middleware::common;

use strict;
use Scalar::Util qw(blessed);
use Data::Dumper;
use middleware::context;
use config; 
use utils::httpresponse;

sub checkContext {

    my $context = shift;

    if(!defined blessed($context) || !$context->isa('middleware::context')) {
        die("Impossibile processare la richiesta: creare un contesto prima!");
    }

}

sub createContext {

    my $callback = shift;

    return sub {

        my $context = middleware::context->new();

        my $c = shift;

        $context->{c} = $c;

        $callback->($context);

    };

}

sub setServiceLocator {

    my $callback = shift;

    return sub {

        my $context = shift;

        checkContext($context);

        $context->{serviceLocator} = config::getServiceLocator();

        $callback->($context);

    };

}

sub setPrincipal {

    my $callback = shift; # TODO parti da qui

    return sub {

        my $context = shift;

        checkContext($context);

        my $rauthservice = $context->{serviceLocator}->get("authservice");

        if($rauthservice->error()) {
            utils::httpresponse::interalse($context->{c}, result::error->new("Errore durante l'elaborazione della richiesta"));
            return; 
        }

        my $authservice = $rauthservice->value();

        my $authentication = $authservice->authenticate($context->{c}->req->headers->header("x-bgcontrol-token"));

        if($authentication->error()) {
            utils::httpresponse::unauth($context->{c}, result::error->new("Impossibile autenticare l'utente"));
            return;
        }

        $context->{principal} = $authentication->value(); 

        $callback->($context);

    };

}

sub loadDependencies {

    my $dependecyNameList = shift;
    my $callback = shift;

    sub {

        my $context = shift;

        checkContext($context);

        if(!defined $context->{serviceLocator}) {
            utils::httpresponse::interalse($context->{c}, result::error->new("Errore durante l'elaborazione della richiesta: nessun service locator fornito"));
            return; 
        }

        my $dependencies = {};

        for(my $i = 0; $i < scalar(@$dependecyNameList); $i++) {

            my $dependencyName = $dependecyNameList->[$i];

            my $rservice = $context->{serviceLocator}->get($dependencyName);

            if($rservice->error()) {
                utils::httpresponse::interalse($context->{c}, result::error->new("Errore durante l'elaborazione della richiesta: impossibile caricare una o più dipendeze ($dependencyName)"));
                return; 
            }

            $dependencies->{$dependencyName} = $rservice->value();

        }

        $context->{dependencies} = $dependencies;

        $callback->($context);

    };

}

sub createAuthenticatedContext {

    my $callback = shift;
    my $dependecyNameList = shift || [];

    return createContext(
        setServiceLocator(
            loadDependencies(
                $dependecyNameList, 
                setPrincipal(
                    $callback
                )
            )
        )
    );

}

1;