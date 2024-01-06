package utils::servicelocator;

use strict;
use result::value;
use result::error;


sub new {
	
	my $class = shift;
	
	my $self = {
		dependencies => {}, 
		singletons => {}, 
		resolvings => []
	};
	
	bless($self, $class);
	
	return $self;
	
}

sub add {
	
	my $self = shift;
	my $dependency = shift;
		
	$self->{dependencies}->{$dependency->{name}} = $dependency;
	
	return $self;
	
}

sub get {
	
	my $self = shift;
	my $dependencyName = shift;

	return $self->resolve($dependencyName);
	
}

sub resolve {
	
	my $self = shift;
	my $dependencyName = shift;
	
	my $dependency = $self->{dependencies}->{$dependencyName};
	
	if($dependency->{singleton} && defined $self->{singletons}->{$dependencyName}) {
		return result::value->new($self->{singletons}->{$dependencyName});
	}
		
	if(grep(/^$dependencyName$/, @{$self->{resolvings}})) {
		return result::error->new("Impossibile determinare la dipendenza: esiste un ciclo tra esse ($dependencyName)");
	}
	
	push(@{$self->{resolvings}}, $dependency->{name});
		
	if(!defined $dependency->{dependsOn} || scalar(@{$dependency->{dependsOn}}) == 0) {
		
		pop(@{$self->{resolvings}});
		
		my $instance = $dependency->{factory}->($self);
	
		if($dependency->{singleton}) {
			$self->{singletons}->{$dependencyName} = $instance;
		}
				
		return result::value->new($instance);
		
	}
	
	my @resolveds = ($self);
	
	for(my $i = 0; $i < scalar(@{$dependency->{dependsOn}}); $i++) {
				
		my $dependOn = $dependency->{dependsOn}->[$i];
		
		if($dependOn->{type} eq "obj") {

            my $rresolved = $self->resolve($dependOn->{name});

            if($rresolved->error()) {
                return $rresolved;
            }
			
			push(@resolveds, $rresolved->value());
							
		} elsif($dependOn->{type} eq "val") {
			
			push(@resolveds, $dependOn->{name});
						
		} else {
						
			return result::error->new("Impossibile determinare la dipendenza");
			
		}
		
	}
	
	pop(@{$self->{resolvings}});
	
	my $instance = $dependency->{factory}->(@resolveds);
	
	if($dependency->{singleton}) {
		$self->{singletons}->{$dependencyName} = $instance;
	}
		
	return result::value->new($instance);
	
}

1;