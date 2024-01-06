package dbutils::dbtemplate;

use strict;
use DBI;
use result::value;
use result::error;


sub new {

    my $class = shift;

    my $self = {
        dbh => 0, 
        ref => 0, 
        config => shift
    };

    bless($self, $class);

    return $self;

}

sub connect {

    my $self = shift;
    my $callback = shift;

    if($self->{ref} == 0) {

        my $rdbh = getDbh($self->{config});

        if($rdbh->error()) {
            return result::error->new("Impossibile collegarsi al database: si è verificato un errore tecnico");
        }

        $self->{dbh} = $rdbh->value();

    }

    $self->{ref}++;

    my $rcallback = $callback->($self->{dbh});
    my $result = $rcallback;

    if(!defined $rcallback) {
        $result = result::error->new("Your callback must define a result, even it is a none");
    }

    $self->{ref}--;

    if($self->{ref} == 0) {
        $self->{dbh}->disconnect();
        $self->{dbh} = 0;
    }

    return $rcallback;

}

sub getDbh {

    my $config = shift; 

    my $driver   = $config->{driver};
    my $database = $config->{database};
    my $dsn = "DBI:$driver:dbname=$database";
    my $username = $config->{username};
    my $password = $config->{password};
    my $dbh = DBI->connect($dsn, $username, $password);

    return defined $dbh ? 
        result::value->new($dbh) : 
        result::error->new("Impossibile collegarsi al database: si è verificato un errore tecnico"); # $DBI::errstr?

}

1;