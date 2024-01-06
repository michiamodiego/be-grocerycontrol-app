package config;

use strict;
use utils::servicelocator;
use dbutils::dbtemplate;
use dbutils::txtemplate;
use services::userservice;
use services::authservice;
use services::marketservice;
use services::productservice;
use services::statservice;


sub getServiceLocator {
    return utils::servicelocator->new()
        ->add({ 
            name => "dbtemplate", 
            factory => sub { 
                return dbutils::dbtemplate->new(
                    {
                        driver => "SQLite", 
                        database => "/home/diego/bgcontrol/database.db", # WARINING: This is just an example, keep it out from any public folder
                        username => "", # Better if you fetch it from the environement or your wallet
                        password => ""  # Better if you fetch it from the environement or your wallet
                    }
                ); 
            }, 
            singleton => 1
        })
        ->add({ 
            name => "txtemplate", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                return dbutils::txtemplate->new($dbtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}
            ],
            singleton => 1
        })
        ->add({ 
            name => "userservice", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                return services::userservice->new($dbtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}
            ]
        })
        ->add({ 
            name => "authservice", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                my $txtemplate = shift;
                return services::authservice->new($dbtemplate, $txtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}, 
                {name => "userservice", type => "obj"}
            ],
        })
        ->add({ 
            name => "marketservice", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                my $txtemplate = shift;
                return services::marketservice->new($dbtemplate, $txtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}, 
                {name => "txtemplate", type => "obj"}
            ]
        })
        ->add({ 
            name => "productservice", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                my $txtemplate = shift;
                return services::productservice->new($dbtemplate, $txtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}, 
                {name => "txtemplate", type => "obj"}
            ]
        })
        ->add({ 
            name => "statservice", 
            factory => sub { 
                my $servicelocator = shift;
                my $dbtemplate = shift;
                my $txtemplate = shift;
                return services::statservice->new($dbtemplate, $txtemplate); 
            }, 
            dependsOn => [
                {name => "dbtemplate", type => "obj"}, 
                {name => "txtemplate", type => "obj"}
            ]
        });
}

1;