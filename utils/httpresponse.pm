package utils::httpresponse;

use strict;


sub valueOrBadRequest {

    my $c = shift; 
    my $result = shift;

    if($result->error()) {
        badrequest($c, $result);
    } else {
        $c->render(json => $result->value());
    }

}

sub valueOrInternalSE {

    my $c = shift; 
    my $result = shift;

    if($result->error()) {
        internalse($c, $result);
    } else {
        $c->render(json => $result->value());
    }

}

sub internalse {

    push(@_, 500);

    return error(@_);

}

sub badrequest {

    push(@_, 400);

    return error(@_);

}

sub unauth {

    push(@_, 401);

    return error(@_);

}

sub error {

    my $c = shift;
    my $result = shift;
    my $code = shift;

    $c->res->code($code);
    $c->res->headers->header('x-bgcontrol-error', $result->cause());
    $c->render(json => {});

}

1;