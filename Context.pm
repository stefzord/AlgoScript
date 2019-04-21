package Context;
use AST;
use 5.010;

sub New{
	my $parent = shift;
	$parent = ['NULL'] if(!defined $parent);
	my $innerContext = {};
	return ['CONTEXT',$innerContext, $parent];
}

sub setParent{
	my $context = shift;
	my $parent  = shift;
	$context->[2] = $parent;
	return $context;
}

sub get{
	my $context = shift;
	my $name    = shift;
	return AST::ERROR("N'est pas un context " . Dumper($context)) if(!AST::EstCONTEXT($context));
	my $value = $context->[1]->{$name};
	if(defined $value){
		return $value;
	}else{
		my $parent =$context->[2];
		if(AST::EstCONTEXT($parent)){
			return get($parent, $name);
		}else{
			return undef;
		}
	}
}

# Pour l'instant on ecrit 
# dans la premiere variable existante
# on affinera plus tard
sub set{
	my $context = shift;
	my $name    = shift;
	my $value   = shift;

	return AST::ERROR("N'est pas un context " . Dumper($context)) if(!AST::EstCONTEXT($context));

	if(defined $context->[1]->{$name}){
		$context->[1]->{$name} = $value;
	}else{
		my $parent = $context->[2];
		if(AST::EstCONTEXT($parent)){
			set($parent, $name, $value);
		}else{
			#On cree la variable !
			$context->[1]->{$name} = $value;
		}
	}
}
##############################################

1;
