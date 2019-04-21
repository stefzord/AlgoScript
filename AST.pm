package AST;
use 5.010;

##########################################
# AST: Une reference de tableau
# AST->[0] = Nom du Noeud
# ########################################

sub Est_de_TYPE{
	my ($AST,$type) = @_;
	return 1 if($AST->[0] eq $type);
	return 0;
}

sub OR{
	my ($val1, $val2) = @_;
	# $val1 et $val2 sont aussi des AST
	return ['OR', $val1, $val2];
}

sub AND{
	my ($val1, $val2) = @_;
	# $val1, $val2 sont aussi des AST
	return ['AND', $val1, $val2];
}

sub XOR{
	my ($val1, $val2) = @_;
	# $val1, $val2 sont aussi des AST
	return ['XOR', $val1, $val2];
}

sub NOT{
	my $val = shift;
	return ['NOT', $val];
}

sub VRAI{
	return ['BOOLEAN','VRAI'];
}
sub EstVRAI{
	my $value = shift;
	return 1 if($value->[0] eq 'BOOLEAN' && $value->[1] eq 'VRAI');
	return 0;
}

sub FAUX{
	return ['BOOLEAN','FAUX'];
}

sub EstFAUX{
	my $value = shift;
	return 1 if($value->[0] eq 'BOOLEAN' && $value->[1] eq 'FAUX');
	return 0;
}

sub EstNUMERIC{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'NUMERIC'));
	return 0;
}

sub EstBOOLEAN{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'BOOLEAN'));
	return 0;
}

sub EstID{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'ID'));
	return 0;
}

sub EstLAMBDA{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'LAMBDA'));
	return 0;
}
sub EstTABLO{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'TABLO'));
	return 0;
}
sub EstDEFTABLO{
	my $value = shift;
	return 1 if(Est_de_TYPE($value, 'DEFTABLO'));
	return 0;
}

sub EstCONTEXT{
	my $value = shift;
	#return 0 unless(defined $value);#Un context null n'en est pas un
	return 1 if(Est_de_TYPE($value, 'CONTEXT'));
	return 0;
}

sub TABLO{
	my $tablo = shift;
	my $localFunc = sub{
		my $action = shift;
		return $tablo->[$action->[1]] if(EstNUMERIC($action));
		return $tablo->[0] if(EstSTRING($action) && $action->[1] eq 'maillon');
		if(EstSTRING($action) && $action->[1] eq 'suite'){
			#return MakeAST_NUMERIC(0) if(!defined $tablo || $tablo == [] || scalar(@$tablo)==1);
			return ['VOID'] if(!defined $tablo || $tablo == [] || scalar(@$tablo)==1);
			my @newTab = @$tablo;
			shift(@newTab);
			return TABLO(\@newTab);
		}
		return ERROR("Methode ".$action->[1]." non definie sur les tableaux !");
	};
	return ['TABLO', $localFunc, $tablo];
}

sub ASSIGN{
	my ($name, $value) = @_;
	return ['ASSIGN', ['ID',$name], $value];
}

sub EstUneERREUR{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'ERROR');
	return 0;
}

sub ERROR{
	my $reason = shift;
	my $where  = shift;
	my $subError = shift;
	return ['ERROR', $reason];
}

sub NULL{
	return ['NULL'];
}
sub EstNULL{
	my $valeur = shift;
	return 0 if(ref $valeur ne 'ARRAY');
	return 1 if($valeur->[0] eq 'NULL');
	return 0;
}
sub EstVOID{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'VOID');
	return 0;
}
sub EstNOTHING{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'NOTHING');
	return 0;
}

# A verifier l'utilite de cette fonction
sub EstLISTINSTRUCTIONS{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'LIST_INSTRUCTIONS');
	return 0;
}

sub NUMERIC{
	my $value = shift;
	#Il faudrait verifier que $value
	#soit bien un numeric !
	return ['NUMERIC', $value];
}

sub STRING{
	my $value = shift;
	return ['STRING', $value];
}

sub EstSTRING{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'STRING');
	return 0;
}

sub EstSTRINGQUOTE{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'STRINGQUOTE');
	return 0;
}

sub LIST_VARIABLES{
	my $context = shift;
	my @keys = keys %$context;
	my $makeList;
	$makeList = sub{
		my $clefs = shift;
		if(@$clefs){
			my $clef = pop @$clefs;
			say "$clef";
			my $value = $context->{$clef};
			return ['LIST_INSTRUCTIONS', ASSIGN($clef,$value),
				$makeList->($clefs)] if(@$clefs);
			return ['LIST_INSTRUCTIONS', ASSIGN($clef,$value),
				NULL()];
		}else{
			#Aucune variable n'est definie
			return ['VOID'];
		}
	};
	return $makeList->(\@keys);
}

sub ADD{
	my ($lvalue, $rvalue)=@_;
	return ['ADD', $lvalue, $rvalue];
}
sub SUBS{
	my ($lvalue, $rvalue)=@_;
	return ['SUBS', $lvalue, $rvalue];
}
sub MULT{
	my ($lvalue, $rvalue)=@_;
	return ['MULT', $lvalue, $rvalue];
}
sub DIV{
	my ($lvalue, $rvalue)=@_;
	return ['DIV', $lvalue, $rvalue];
}
sub INTERNALFUNC{
	my $func = shift;
	return ['INTERNALFUNC', $func];
}
sub getINTERNALFUNC{
	my $func = shift;
	return $func->[1] if($func->[0] eq 'INTERNALFUNC');
	return ERROR("N'est pas une fonction interne " . $func->[0]);
}
sub EstINTERNALFUNC{
	my $valeur = shift;
	return 1 if($valeur->[0] eq 'INTERNALFUNC');
	return 0;
}



1;
