#!/usr/bin/perl

use lib qw(/home/diego/bgcontrol/);

use Data::Dumper;

use dbutils::dbtemplate;
use dbutils::txtemplate;
use result::placeholder;

my $dbtemplate = dbutils::dbtemplate->new({});
my $txtemplate = dbutils::txtemplate->new($dbtemplate);

my $result = result::placeholder->new();

$txtemplate->open(sub {

    my $dbh = shift;
    my $setToRollback = shift;

    my $query = $dbh->prepare("select * from user");
    $query->execute();

    my $resultset = $query->fetchall_arrayref();

    $txtemplate->open(sub {

        my $dbh = shift;
        my $setToRollback = shift;

        my $query = $dbh->prepare("select * from user");
        $query->execute();

        my $resultset = $query->fetchall_arrayref();

        $result->setError("Kio");

        print "1";
        print Dumper(\$resultset);

    });

    print "2";
    print Dumper(\$resultset);


});

my $rr = $result->resolve();

print "A big error: \n\n";
print Dumper($rr);