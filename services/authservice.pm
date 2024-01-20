package services::authservice;

use strict;
use Data::Dumper;
use Digest::SHA;
use Data::GUID;
use DateTime;
use result::value;
use result::error;


sub new {

    my $class = shift;
    my $dbtemplate = shift;
    my $userservice = shift;
    
    my $self = {
        dbtemplate => $dbtemplate, 
        userservice => $userservice
    };

    bless($self, $class);
    
    return $self;

}

sub login {

    my $self = shift;
    my $username = shift;
    my $password = Digest::SHA::sha256_base64(shift);

    my $ruser = $self->{userservice}->getUserByUsername($username);

    if($ruser->error()) {
        return result::error->new("Impossibile loggare l'utente: nessun utente trovato");
    }

    my $user = $ruser->value();

    if($password ne $user->{password}) {
        return result::error->new("Impossibile loggare l'utente: credenziali errate");
    }

    my $rtoken = $self->createToken($user);

    if($rtoken->error()) {
        return result::error->new("Impossibile loggare l'utente: impossibile geneare il token");
    }

    my $raccount = $self->{userservice}->getAccountById($user->{id});

    if($raccount->error()) {
        return result::error->new("Impossibile loggare l'utente");
    }

    return result::value->new({
        account => $raccount->value(), 
        token => $rtoken->value()
    });

}

sub authenticate {

    my $self = shift;
    my $token = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $rcurrentToken = $self->getToken($token);

        if($rcurrentToken->error()) {
            return result::error->new("Impossibile autenticare l'utente: impossibile recupeare il token");
        }

        my $currentToken = $rcurrentToken->value();
        my $now = DateTime->now();

        if(DateTime->compare(DateTime->from_epoch(epoch => $currentToken->{expiresAt}), $now) <= 0) {
            return result::error->new("Impossibile autenticare l'utente: il token non è valido");
        }

        my $rrefreshedToken = $self->refreshToken($currentToken);

        if($rrefreshedToken->error()) {
            return result::error->new("Impossibile autenticare l'utente: impossibile aggiorare il token");
        }

        my $ruser = $self->{userservice}->getUserById($rrefreshedToken->value()->{userId});

        if($ruser->error()) {
            return result::error->new("Impossibile autenticare l'utente");
        }

        return $ruser;

    });

}

sub getToken {

    my $self = shift;
    my $token = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $statement = q|
            SELECT 
                id, 
                user_id, 
                token, 
                expires_at 
            FROM 
                token 
            WHERE 
                token = ?
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($token)) {
            return result::error->new("Impossibile recuperare il token: si è verificato un errore tecnico");
        }

        my $resultset = $query->fetchall_arrayref();

        if(scalar(@{$resultset}) == 0) {            
            return result::error->new("Impossibile recuperare il token");
        }

        return result::value->new({
            userId => $resultset->[0][1], 
            token => $token, 
            expiresAt => $resultset->[0][3]
        });

    });

}

sub createToken {

    my $self = shift;
    my $user = shift;

    return $self->{dbtemplate}->connect(sub {

        my $dbh = shift;

        my $token = Data::GUID->new->as_string;
        my $expiresAt = DateTime->now();

        $expiresAt->add(days => 1);

        my $statement = q|
            INSERT INTO token (
                user_id, 
                token, 
                expires_at
            ) VALUES (?, ?, ?)
        |;

        my $query = $dbh->prepare($statement);

        if(!defined $query || !$query->execute($user->{id}, $token, $expiresAt->epoch())) {
            return result::error->new("Impossibile creare il token: si è verificato un errore tecnico");
        }

        return result::value->new({
            userId => $user->{id}, 
            token => $token, 
            expiresAt => $expiresAt->epoch()
        });

    });

}

sub refreshToken {

    my $self = shift;
    my $token = shift;

    return $self->{dbtemplate}->connect(sub { 

        my $dbh = shift;
        
        my $newExpiresAt = DateTime->now();

        $newExpiresAt->add(days => 1);

        my $statement = q|
            UPDATE 
                token 
            SET 
                expires_at = ? 
            WHERE 
                token = ? AND 
                expires_at = ?
        |;
        
        my $update = $dbh->prepare($statement);

        my @params = (
            $newExpiresAt->epoch(), 
            $token->{token}, 
            $token->{expiresAt}
        );

        if(!defined $update || !$update->execute(@params)) {
            return result::error->new("Impossibile refreshare il token: si è verificato un errore tecnico");
        }

        my $rrefreshedToken = $self->getToken($token->{token});

        if($rrefreshedToken->error()) {
            return result::error->new("Impossibile refreshare il token");
        }

        return result::value->new($rrefreshedToken->value());

    });

}

1;