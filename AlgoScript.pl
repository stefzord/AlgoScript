#!/usr/bin/perl 

use strict;
use warnings;
use 5.010;
use Data::Dumper;
use Time::HiRes;
use ParserRecdescent;
use Compile;
use AST;
#use Curses;
use Term::ReadLine;

use vars qw($AST_Build);

# Idee pour sauvegarder l'AST:
# http://alumnus.caltech.edu/~svhwan/prodScript/useDataDumper.html

# FIXME: Bug dans Concatene, ["a","b","c"] & "e"
# concatene l'adresse du tableau avec "e"
# FIXME: La variable speciale CONTEXT ne fonctionne plus
# Elle est basee sur les contextes HASH alors qu'ils
# sont en ARRAY
# VERSION KSCRIPT 0.007:
# 	- Utilisation de 3(2+1)
# 	pour les numeric, les vecteurs et strings
# 	Syntaxe: pour x=3 affiche x.
# 	#Attention au point final dans la syntaxe du 'pour'
# 	#- Utilisation de y=3x+2 par exemple
# 	#Suppression de cette fonctionnalite
# VERSION KSCRIPT 0.006:
# 	- Ajout de range [a..b] pour etre utilise 
# 	dans les tableaux
# VERSION KSCRIPT 0.005:
# 	- Ajout de l'operateur '&' de concatenation
# 	pour les STRINGs et les TABLOs
# 	- operateurs +,-,* et / pour les TABLOs
# 	on effectue ces operations 2 a 2 sur chaques
# 	paires d'elements des TABLOs
# VERSION KSCRIPT 0.004:
# 	- Ajout "pour chaque"
# VERSION KSCRIPT 0.003:
# 	- Utilisation du mot clef rien pour definir
# 	la fin d'un tableau et d'un string
# 	On l'utilise aussi pour afficher
# 	un retour chariot avec "affiche rien"
# VERSION KSCRIPT 0.002:
# 	- Ajout des tableaux
# 	sous la forme [element0, element1, ... ]
# 	Utilisent l'operateur () pour acceder aux element.
# VERSION KSCRIPT 0.001:
# 	- Suppression de l'acces aux fonctions via les variables
# 	une seule methode existe l'operateur bracket
# VERSION KSCRIPT:
# 	- Ajout de operateur () pour les fonctions
# 	et chaines de caracteres
# VERSION ALPHA10:
# 	- Correction des bugs les lambda
# 		Utilisation differente des contexts des fonctions
# Ajout de TANT QUE
# Modification de la fonction "load" afin de charger du
# 	code "esthetique" (on peut mettre des retour chariot
# 	un peu partout), les ";" etant ajoutes au chargement
# Ajout de pour var1=... , var2= ... :
#     on ajoute ainsi un nouveau contexte
# Ajout de supperieur stricte
# Une ligne commencant par # ignoree (pas par le language
#     mais par l'interpreteur)
# BUG dans les lambda, une fonction de fonction de fonction
#     tourne en boucle !
# Ajout des lambda expression sous la forme \(){}
# Ajout du keyword Input (entree? | ?) pour acquerir des donnees
# Ajout d'un context pour chaque fonction
# Ajout des fonctions (BETA)
# AJOUT DES STRINGS (ALPHA)
# AJOUT boucle "pour i = x jusqu'a y: instructions suivant"


my $GLOBAL_MODE = 'LIGNE';#On peut aussi avoir 'ECRAN'
my @GLOBAL_GPIO_PIN = ();
foreach my $i (1..40){
	push @GLOBAL_GPIO_PIN ,"UNDEF";
}


 
##############################################
# On s'occupe du context !
##############################################

sub Context_New{
	my $parent = shift;
	$parent = ['NULL'] if(!defined $parent);
	my $innerContext = {};
	return ['CONTEXT',$innerContext, $parent];
}

sub Context_setParent{
	my $context = shift;
	my $parent  = shift;
	$context->[2] = $parent;
	return $context;
}

sub Context_get{
	my $context = shift;
	my $name    = shift;
	return AST::ERROR("N'est pas un context " . Dumper($context)) if(!AST::EstCONTEXT($context));
	my $value = $context->[1]->{$name};
	if(defined $value){
		#print "Context_get value:" . Dumper($value). "\n";
		return $value;
	}else{
		my $parent =$context->[2];
		#print "Context_get value: indefinie\n";
		if(AST::EstCONTEXT($parent)){
			#print "Context_get value: parent est un context, on lui passe la main\n";
			return Context_get($parent, $name);
		}else{
			#print "Context_get value: parent n'est pas un context, on ne renvoie rien !\n";
			return undef;
		}
	}
}

# Pour l'instant on ecrit 
# dans la premiere variable existante
# on affinera plus tard
sub Context_set{
	my $context = shift;
	my $name    = shift;
	my $value   = shift;

	return AST::ERROR("N'est pas un context " . Dumper($context)) if(!AST::EstCONTEXT($context));

	if(defined $context->[1]->{$name}){
		$context->[1]->{$name} = $value;
	}else{
		my $parent = $context->[2];
		if(AST::EstCONTEXT($parent)){
			Context_set($parent, $name, $value);
		}else{
			#On cree la variable !
			$context->[1]->{$name} = $value;
		}
	}
}
##############################################

	# Renvois une fonction renvoyant
	# Vrais quelque soient ses arguments
	sub MakeVRAI{
		return sub{
			#return MakeAST_VRAI();
			return AST::VRAI();
		}
	}

	# Renvois une fonction renvoyant
	# Faux quelque soient ses arguments
	sub MakeFAUX{
		return sub{
			#return MakeAST_FAUX();
			return AST::FAUX();
		}
	}



sub MakeNOT{
	# Renvois l'inverse de la fonction
	# en entree
	my $porte = shift;
	return sub{
		# Les valeur sont dans
		# une reference de tableau
		my $values = shift;
		my $valeur = $porte->($values);
		return undef if(!defined $valeur);
		#return 0 if($valeur);
		#return $valeur if(EstUneERREUR($valeur));
		return $valeur if(AST::EstUneERREUR($valeur));
		#return MakeAST_FAUX() if(EstVRAI($valeur));
		return AST::FAUX() if(AST::EstVRAI($valeur));
		#return MakeAST_VRAI() if(EstFAUX ($valeur));
		return AST::VRAI() if(AST::EstFAUX ($valeur));
		return AST::ERROR("N'EST PAS UN BOOLEAN", $valeur);
	}
}
sub MakeAND{
	my @portes = @_;
	return sub{
		# Les valeurs sont dans
		# une reference de tableau
		my $values = shift;
		# Un AND est faux si au moins
		# une de ses valeur est faux
		foreach my $porte (@portes){
			my $valeur = $porte->($values);
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			return AST::FAUX() if(AST::EstFAUX($valeur));
		}
		# Aucune valeur n'est fausse!
		return AST::VRAI();
	}
}
sub MakeOR{
	my @portes = @_;
	return sub{
		# Les valeurs sont dans
		# une reference de tableau
		my $values = shift;
		# Un OR est vrai si au moins
		# une de ses valeur est vrai
		foreach my $porte (@portes){
			my $valeur = $porte->($values);
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			return AST::VRAI() if(AST::EstVRAI($valeur));
		}
		# Aucune valeur n'est vrai !
		return AST::FAUX();
	}
}
sub MakeXOR{
	# Pour le XOR nous n'acceptons que 2 entrees
	my ($A, $B) = @_;
	return sub{
		# Les valeurs sont dans
		# une reference de tableau
		my $values = shift;
		# XOR = (a && !b) || (!a && b)
		my $Not_A = MakeNOT($A);
		my $Not_B = MakeNOT($B);
		my $AND_1 = MakeAND($A, $Not_B);
		my $AND_2 = MakeAND($Not_A, $B);
		my $XOR = MakeOR($AND_1, $AND_2);
		return $XOR->($values);
	}
}



#On enleve les elements NOTHING
#des AST
sub RemoveNOTHING{
	my $AST = shift;
	my $nbElem = scalar(@$AST);
	my $name = $AST->[0];
	my $deep = shift;
	#print "RemoveNOTHING: $deep \n" if(defined $deep);

	return $AST if($nbElem ==1);
	
	if(($name eq 'CONDITION')||($name eq 'POURCHAQUE')){
		my $tab=[];
		$tab->[0] = $AST->[0];
		foreach my $i (1..$nbElem-1){
			$tab->[$i] = RemoveNOTHING($AST->[$i], $deep+1);
		}
		return $tab;
	}
	if($name eq 'BOUCLEPOUR'){
		my $tab=[];
		$tab->[0] = $AST->[0];
		$tab->[1] = $AST->[1];
		foreach my $i (2..$nbElem-1){
			$tab->[$i] = RemoveNOTHING($AST->[$i], $deep+1);
		}
		return $tab;
	}
	if($nbElem ==2){
		return [$AST->[0],RemoveNOTHING($AST->[1], $deep+1)] if(ref($AST->[1]) eq 'ARRAY');
		return $AST;
	}
	if($nbElem ==3){
		my $ast2 = RemoveNOTHING($AST->[2], $deep+1);
		my $ast1 = RemoveNOTHING($AST->[1], $deep+1);
		return $ast1 if(AST::EstNOTHING($ast2));
		return [$AST->[0], $ast1, $ast2];
	}
	print "DANS RemoveNOTHING: AST $name inconnu\n";
}
##########################################
# Renvoie une fonction correspondant 
# a l'AST
# ########################################
sub MakeSUB{
	my $AST = shift;
	return MakeSUB_AST_ERROR([$AST]) if(ref($AST) ne 'ARRAY');
	return MakeSUB_OR    ($AST) if($AST->[0] eq 'OR'    );
	return MakeSUB_AND   ($AST) if($AST->[0] eq 'AND'   );
	return MakeSUB_XOR   ($AST) if($AST->[0] eq 'XOR'   );
	return MakeSUB_NOT   ($AST) if($AST->[0] eq 'NOT'   );
	return MakeSUB_ADD   ($AST) if($AST->[0] eq 'ADD'   );
	return MakeSUB_SUBS  ($AST) if($AST->[0] eq 'SUBS'  );
	return MakeSUB_MULT  ($AST) if($AST->[0] eq 'MULT'  );
	return MakeSUB_DIV   ($AST) if($AST->[0] eq 'DIV'  );
	return MakeSUB_CONCATENE($AST) if($AST->[0] eq 'CONCATENE');
	return MakeSUB_VRAI  ($AST) if($AST->[0] eq 'BOOLEAN' && $AST->[1] eq 'VRAI');
	return MakeSUB_FAUX  ($AST) if($AST->[0] eq 'BOOLEAN' && $AST->[1] eq 'FAUX' );
	return MakeSUB_VOID  ($AST) if($AST->[0] eq 'VOID'  );#En TEST !
	return MakeSUB_NOTHING($AST) if($AST->[0] eq 'NOTHING');
	return MakeSUB_ASSIGN($AST) if($AST->[0] eq 'ASSIGN');
	return MakeSUB_AFFECT($AST) if($AST->[0] eq 'AFFECT');
	return MakeSUB_ID    ($AST) if($AST->[0] eq 'ID'    );
	return MakeSUB_LIST_INSTRUCTIONS($AST) if($AST->[0] eq 'LIST_INSTRUCTIONS');
	return MakeSUB_NUMERIC  ($AST) if($AST->[0] eq 'NUMERIC');
	return MakeSUB_CONDITION($AST) if($AST->[0] eq 'CONDITION');
	return MakeSUB_TANTQUE($AST) if($AST->[0] eq 'TANTQUE');
	return MakeSUB_EQUALITE ($AST) if($AST->[0] eq 'EQUALITE' );
	return MakeSUB_STRICTSUP($AST) if($AST->[0] eq 'STRICTSUP' );
	return MakeSUB_AFFICHE  ($AST) if($AST->[0] eq 'AFFICHE'  );
	return MakeSUB_STRING($AST) if($AST->[0] eq 'STRING');
	return MakeSUB_STRINGQUOTE($AST) if($AST->[0] eq 'STRINGQUOTE');
	return MakeSUB_BOUCLEPOUR($AST) if($AST->[0] eq 'BOUCLEPOUR');
	return MakeSUB_POURCONTEXT($AST) if($AST->[0] eq 'POURCONTEXT');
	return MakeSUB_POURCHAQUE($AST) if($AST->[0] eq 'POURCHAQUE');
	return MakeSUB_FUNCASSIGN($AST) if($AST->[0] eq 'FUNCASSIGN');
	#return MakeSUB_FUNC($AST) if($AST->[0] eq 'FUNC');
	return MakeSUB_LAMBDA($AST) if($AST->[0] eq 'LAMBDA');
	return MakeSUB_INTERNALFUNC($AST) if($AST->[0] eq 'INTERNALFUNC');
	return MakeSUB_DEFLAMBDA($AST) if($AST->[0] eq 'DEFLAMBDA');
	return MakeSUB_DEFRANGE ($AST) if($AST->[0] eq 'DEFRANGE');
	return MakeSUB_DEFTABLO($AST) if($AST->[0] eq 'DEFTABLO');
	return MakeSUB_TABLO($AST) if($AST->[0] eq 'TABLO');
	return MakeSUB_BRACKET($AST) if($AST->[0] eq 'BRACKET');
	return MakeSUB_INPUT($AST) if($AST->[0] eq 'INPUT');
	return MakeSUB_ERROR($AST) if($AST->[0] eq 'ERROR');
	return MakeSUB_INSPECT($AST) if($AST->[0] eq 'INSPECT');
	return MakeSUB_AST_ERROR($AST);
}

sub MakeSUB_AST_ERROR{
	my $AST = shift;
	return sub{
		my $astName = $AST->[0];
		#print "ERREUR DANS ERROR:" . Dumper($AST);
		return AST::ERROR("AST $astName inconnu") if($astName);
		return AST::ERROR("SYNTAX ERROR");
	}
}
# ERREUR NON CATCHEE !!
# CECI NE DEVRAIT PAS ARRIVER !!!!
sub MakeSUB_ERROR{
	my $AST = shift;
	return sub{
		my $astName = $AST->[0];
		#return AST::ERROR("ERREUR NON CATCHEE: AST $astName inconnu") if($astName);
		return $AST if($astName);
		return AST::ERROR("ERREUR NON CATCHEE: SYNTAX ERROR");
	}
}

sub MakeSUB_INSPECT{
	my $AST = shift;
	return sub{
		my $context = shift;
		print "INSPECT: " . Dumper($AST);
		if($AST->[1]->[0] eq 'ID'){
			print "DEEPER: ";
			my $name = $AST->[1]->[1];
			my $value = Context_get($context, $name);
			if(AST::EstLAMBDA($value)){
				print Dumper($value->[2]);
			}else{
				print Dumper($value);
			}
		}
		return ['VOID'];
	}
}

sub MakeSUB_OR{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);
	return MakeOR($sub_l, $sub_r);
}

sub MakeSUB_AND{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	return MakeAND(MakeSUB($AST_L),MakeSUB($AST_R));
}


sub MakeSUB_XOR{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	return MakeXOR(MakeSUB($AST_L),MakeSUB($AST_R));
}

sub MakeSUB_NOT{
	my $AST = shift;
	my $AST_Val = $AST->[1];
	return MakeNOT(MakeSUB($AST_Val));
}

sub MakeSUB_VRAI{
	my $AST = shift;
	return sub{
		#MakeAST_VRAI();
		AST::VRAI();
	}
}

sub MakeSUB_FAUX{
	my $AST = shift;
	return sub{
		#MakeAST_FAUX();
		AST::FAUX();
	}
}

#A verifier la pertinance
sub MakeSUB_VOID{
	my $AST = shift;
	return sub{
		return $AST;
	}
}
sub MakeSUB_NOTHING{
	my $AST = shift;
	return sub{
		return $AST;
	}
}

sub MakeSUB_NUMERIC{
	my $AST = shift;
	return sub{
		AST::NUMERIC($AST->[1]);
	}
}

sub MakeSUB_INTERNALFUNC{
	my $AST = shift;
	return sub{
		return $AST;
	}
}

sub MakeSUB_STRINGQUOTE{
	my $AST = shift;
	my $string = $AST->[1];
	$string =~ s/^\"(.*)\"$/$1/;
	return sub{
		AST::STRING($string);
	}
}

sub MakeSUB_STRING{
	my $AST = shift;
	return sub{
		AST::STRING($AST->[1]);
	}
}
sub MakeSUB_INPUT{
	my $AST = shift;
	return sub{
		my $input=<>;
		chomp($input);
		return AST::NUMERIC($input) if($input =~ /^\s*(\+|\-)?\d+(\.(\d+))*\s*$/);
		return AST::STRING($input);
	}
}

sub MakeSUB_ADD{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);

	my @portes = ($sub_l, $sub_r);
	my $logique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		foreach my $valeur ($lvalue, $rvalue){
			#my $valeur = $porte->($values);
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			#return MakeAST_VRAI() if(EstVRAI($valeur));
			return AST::VRAI() if(AST::EstVRAI($valeur));
		}
		# Aucune valeur n'est vrai !
		return AST::FAUX();
	};
	my $lambda = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		#return ['LAMBDA',$parameters,$code,$context];
		# Pour l'instant on utilise que 1 parametre
		my $parameters = ['LIST_IDENTIFIERS',['ID','x'],['NULL']];
		my $localContext = Context_New();
		#my $code = ['LIST_INSTRUCTIONS',['ADD',$lvalue,$r],['NULL']];
	};
	my $numerique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		return AST::NUMERIC($lvalue->[1] + $rvalue->[1]);
	};

	return sub{
		my $context = shift;
		my $lvalue = $sub_l->($context);
		return $lvalue if(AST::EstUneERREUR($lvalue));
		my $rvalue = $sub_r->($context);
		return $lvalue if(AST::EstNOTHING($rvalue));
		return $rvalue if(AST::EstUneERREUR($rvalue));
		return $numerique->($context,$lvalue,$rvalue) if(AST::EstNUMERIC($lvalue)&& AST::EstNUMERIC($rvalue));
		return $logique->($context,$lvalue,$rvalue)if(AST::EstBOOLEAN($lvalue)&& AST::EstBOOLEAN($rvalue));
		return OperateurSurTABLO($context,$lvalue,$rvalue, \&AST::ADD)if(AST::EstTABLO($lvalue) && AST::EstTABLO($rvalue));
		if(AST::EstTABLO($lvalue) || AST::EstTABLO($rvalue)){
			my $operande;
			my $tablo;
			my $action;
			if(AST::EstTABLO($lvalue)){
				$operande = $rvalue;
				$tablo    = $lvalue;
				$action   = sub{
					my $element = shift;
					return AST::ADD($element,$operande);
				};
			}else{
				$operande = $lvalue;
				$tablo    = $rvalue;
				$action   = sub{
					my $element = shift;
					return AST::ADD($operande, $element);
				};
			}
			return ActionSurChaqueElementDuTABLO($context,$tablo,$action);
		}
		return ConcateneSTRING($context,$lvalue,$rvalue)if(AST::EstSTRING($lvalue) || AST::EstSTRING($rvalue));
		#return $rvalue;
		return AST::ERROR("SYNTAX ERROR: ne peut pas additionner ces 2 types");
	}
}

sub ConcateneSTRING{
	my $context = shift;
	my $lvalue  = shift;
	my $rvalue  = shift;
	return $lvalue if(AST::EstVOID($rvalue));
	return $rvalue if(AST::EstVOID($lvalue));
	return AST::STRING($lvalue->[1] . $rvalue->[1]);
}
sub ActionSurChaqueElementDuTABLO{
	my $context = shift;
	my $tablo   = shift;
	my $action  = shift;
	my $tab = $tablo->[2];
	my @newTab = ();
	foreach my $element (@$tab){
		my $ast= $action->($element);
		my $value = MakeSUB($ast)->($context);
		push(@newTab, $value);
	}
	return AST::TABLO(\@newTab);
}
sub OperateurSurTABLO{
	my $context = shift;
	my $lvalue  = shift;
	my $rvalue  = shift;
	my $MakeAST = shift;
	my $ltab = $lvalue->[2];
	my $rtab = $rvalue->[2];
	my $longL = scalar(@$ltab);
	my $longR = scalar(@$rtab);
	my $minTab;
	my $maxTab;
	my $lmin;
	my $lmax;
	if($longL >= $longR){
		$minTab = $rtab;
		$maxTab = $ltab;
		$lmin = $longR;
		$lmax = $longL;
	}else{
		$minTab = $ltab;
		$maxTab = $rtab;
		$lmin = $longL;
		$lmax = $longR;
	}
	my @newTab = ();
	my $newAST;
	my $ASTValue;
	for (my $i=0; $i< $lmax; $i++){
		if($i<$lmin){
			#$newAST = ['ADD', $ltab->[$i], $rtab->[$i]];
			$newAST = $MakeAST->($ltab->[$i], $rtab->[$i]);
			$ASTValue = MakeSUB($newAST)->($context);
		}else{
			$ASTValue = $maxTab->[$i];
		}
		push(@newTab, $ASTValue);
	}
	return AST::TABLO(\@newTab);
}
sub ConcateneTABLO{
	my $context = shift;
	my $lvalue  = shift;
	my $rvalue  = shift;
	my $ltab = $lvalue->[2];
	my $rtab = $rvalue->[2];
	my @newTab = (@$ltab,@$rtab);
	return AST::TABLO(\@newTab);
}
sub MakeSUB_CONCATENE{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);

	my @portes = ($sub_l, $sub_r);

	my $lambda = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		# Pour l'instant on utilise que 1 parametre
		my $parameters = ['LIST_IDENTIFIERS',['ID','x'],['NULL']];
		my $localContext = Context_New();
	};
	my $numerique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		return AST::STRING($lvalue->[1] . $rvalue->[1]);
	};
	
	return sub{
		my $context = shift;
		my $lvalue = $sub_l->($context);
		return $lvalue if(AST::EstUneERREUR($lvalue));
		my $rvalue = $sub_r->($context);
		return $lvalue if(AST::EstNOTHING($rvalue));
		return $rvalue if(AST::EstUneERREUR($rvalue));
		return $lvalue if(AST::EstVOID($rvalue));
		return $rvalue if(AST::EstVOID($lvalue));
		return $numerique->($context,$lvalue,$rvalue) if(AST::EstNUMERIC($lvalue)&& AST::EstNUMERIC($rvalue));
		return ConcateneTABLO($context,$lvalue,$rvalue)if(AST::EstTABLO($lvalue) && AST::EstTABLO($rvalue));

		return ConcateneSTRING($context,$lvalue,$rvalue)if(AST::EstSTRING($lvalue) || AST::EstSTRING($rvalue));
		return AST::ERROR("SYNTAX ERROR: ne peut pas concatener ces 2 types");
	}
}
sub MakeSUB_SUBS{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);
	#return MakeADD($sub_l, $sub_r);
	my @portes = ($sub_l, $sub_r);
	my $logique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		foreach my $valeur ($lvalue, $rvalue){
			#my $valeur = $porte->($values);
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			#return MakeAST_VRAI() if(EstVRAI($valeur));
			return AST::VRAI() if(AST::EstVRAI($valeur));
		}
		# Aucune valeur n'est vrai !
		return MakeAST_FAUX();
	};
	my $numerique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		return AST::NUMERIC($lvalue->[1] - $rvalue->[1]);
	};
	return sub{
		my $context = shift;
		my $lvalue = $sub_l->($context);
		return $lvalue if(AST::EstUneERREUR($lvalue));
		my $rvalue = $sub_r->($context);
		return $lvalue if(AST::EstNOTHING($rvalue));
		return $rvalue if(AST::EstUneERREUR($rvalue));
		return $numerique->($context,$lvalue,$rvalue) if(AST::EstNUMERIC($lvalue)&& AST::EstNUMERIC($rvalue));
		return $logique->($context,$lvalue,$rvalue)if(AST::EstBOOLEAN($lvalue)&& AST::EstBOOLEAN($rvalue));
		return OperateurSurTABLO($context,$lvalue,$rvalue, \&AST::SUBS)if(AST::EstTABLO($lvalue) && AST::EstTABLO($rvalue));
		if(AST::EstTABLO($lvalue) || AST::EstTABLO($rvalue)){
			my $operande;
			my $tablo;
			my $action;
			if(AST::EstTABLO($lvalue)){
				$operande = $rvalue;
				$tablo    = $lvalue;
				$action   = sub{
					my $element = shift;
					return AST::SUBS($element,$operande);
				};
			}else{
				$operande = $lvalue;
				$tablo    = $rvalue;
				$action   = sub{
					my $element = shift;
					return AST::SUBS($operande, $element);
				};
			}
			return ActionSurChaqueElementDuTABLO($context,$tablo,$action);
		}
		return AST::ERROR("SYNTAX ERROR: ne peut pas soustraire ces 2 types");
	}
}

sub MakeSUB_MULT{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);
	#return MakeADD($sub_l, $sub_r);
	my @portes = ($sub_l, $sub_r);
	my $logique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		foreach my $valeur ($lvalue, $rvalue){
			#my $valeur = $porte->($values);
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			#return MakeAST_VRAI() if(EstVRAI($valeur));
			return AST::VRAI() if(AST::EstVRAI($valeur));
		}
		# Aucune valeur n'est vrai !
		return AST::FAUX();
	};
	my $numerique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		return AST::NUMERIC($lvalue->[1] * $rvalue->[1]);
	};
	my $string = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		my $val = $lvalue->[1];
		my $str = $rvalue->[1];
		return AST::STRING("") if($val == 0);
		my $accu = "";
		foreach my $i (1..$val){
			$accu .= $str;
		}
		return AST::STRING($accu);
	};
	return sub{
		my $context = shift;
		my $lvalue = $sub_l->($context);
		return $lvalue if(AST::EstUneERREUR($lvalue));
		my $rvalue = $sub_r->($context);
		return $lvalue if(AST::EstNOTHING($rvalue));
		return $rvalue if(AST::EstUneERREUR($rvalue));
		return $numerique->($context,$lvalue,$rvalue) if(AST::EstNUMERIC($lvalue)&& AST::EstNUMERIC($rvalue));
		return $logique->($context,$lvalue,$rvalue)if(AST::EstBOOLEAN($lvalue)&& AST::EstBOOLEAN($rvalue));
		return $string->($context,$lvalue,$rvalue)if(AST::EstNUMERIC($lvalue)&& AST::EstSTRING($rvalue));
		return $string->($context,$rvalue,$lvalue)if(AST::EstNUMERIC($rvalue)&& AST::EstSTRING($lvalue));
		return OperateurSurTABLO($context,$lvalue,$rvalue, \&AST::MULT)if(AST::EstTABLO($lvalue) && AST::EstTABLO($rvalue));
		if(AST::EstTABLO($lvalue) || AST::EstTABLO($rvalue)){
			my $operande;
			my $tablo;
			my $action;
			if(AST::EstTABLO($lvalue)){
				$operande = $rvalue;
				$tablo    = $lvalue;
				$action   = sub{
					my $element = shift;
					return AST::MULT($element,$operande);
				};
			}else{
				$operande = $lvalue;
				$tablo    = $rvalue;
				$action   = sub{
					my $element = shift;
					return AST::MULT($operande, $element);
				};
			}
			return ActionSurChaqueElementDuTABLO($context,$tablo,$action);
		}
		return AST::ERROR("SYNTAX ERROR: ne peut pas multiplier ces 2 types");
	}
}

sub MakeSUB_DIV{
	my $AST = shift;
	my $AST_L = $AST->[1];
	my $AST_R = $AST->[2];
	my $sub_l = MakeSUB($AST_L);
	my $sub_r = MakeSUB($AST_R);
	my @portes = ($sub_l, $sub_r);
	my $logique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		foreach my $valeur ($lvalue, $rvalue){
			return undef if(!defined $valeur);
			return $valeur if(AST::EstUneERREUR($valeur));
			#return MakeAST_VRAI() if(EstVRAI($valeur));
			return AST::VRAI() if(AST::EstVRAI($valeur));
		}
		# Aucune valeur n'est vrai !
		return AST::FAUX();
	};
	my $numerique = sub{
		my $context = shift;
		my $lvalue  = shift;
		my $rvalue  = shift;
		return AST::ERROR("Division par zero") if($rvalue->[1] == 0);
		return AST::NUMERIC($lvalue->[1] / $rvalue->[1]);
	};
	return sub{
		my $context = shift;
		my $lvalue = $sub_l->($context);
		return $lvalue if(AST::EstUneERREUR($lvalue));
		my $rvalue = $sub_r->($context);
		return $lvalue if(AST::EstNOTHING($rvalue));
		return $rvalue if(AST::EstUneERREUR($rvalue));
		return $numerique->($context,$lvalue,$rvalue) if(AST::EstNUMERIC($lvalue)&& AST::EstNUMERIC($rvalue));
		return $logique->($context,$lvalue,$rvalue)if(AST::EstBOOLEAN($lvalue)&& AST::EstBOOLEAN($rvalue));
		return OperateurSurTABLO($context,$lvalue,$rvalue, \&AST::DIV)if(AST::EstTABLO($lvalue) && AST::EstTABLO($rvalue));
		if(AST::EstTABLO($lvalue) || AST::EstTABLO($rvalue)){
			my $operande;
			my $tablo;
			my $action;
			if(AST::EstTABLO($lvalue)){
				$operande = $rvalue;
				$tablo    = $lvalue;
				$action   = sub{
					my $element = shift;
					return AST::DIV($element,$operande);
				};
			}else{
				$operande = $lvalue;
				$tablo    = $rvalue;
				$action   = sub{
					my $element = shift;
					return AST::DIV($operande, $element);
				};
			}
			return ActionSurChaqueElementDuTABLO($context,$tablo,$action);
		}
		return AST::ERROR("SYNTAX ERROR: ne peut pas diviser ces 2 types");
	}
} 

sub MakeSUB_AFFECT{
	#Version GLOUTON de assign
	my $AST = shift;
	return sub{
		my $context = shift;
		my $AST_ID = $AST->[1];
		my $AST_VALUE = $AST->[2];
		my $var_name = $AST_ID->[1];
		my $retour = MakeSUB($AST_VALUE)->($context);
		return $retour if(AST::EstUneERREUR($retour));
		Context_set($context, $var_name, $retour);
		return ['VOID'];
	}
}
sub MakeSUB_ASSIGN{
	my $AST = shift;
	return MakeSUB_ASSIGN_LAZY($AST);
}
sub MakeSUB_ASSIGN_LAZY{
	my $AST = shift;
	my $AST_ID = $AST->[1];
	my $AST_VALUE = $AST->[2];
	return sub{
		my $context = shift;
		my $var_name= $AST_ID->[1];
		#L'assignation n'est pas vraiment lazy
		#Si AST_VALUE est une creation de lambda
		$AST_VALUE = MakeSUB($AST_VALUE)->($context)if($AST_VALUE->[0] eq 'DEFLAMBDA');
		Context_set($context, $var_name, $AST_VALUE);
		return ['VOID'];
	}
}
sub MakeSUB_ID{
	my $id = shift;
	return sub{
		my $context = shift;
		my $name = $id->[1];
		return AST::LIST_VARIABLES($context) if($name eq 'CONTEXT');
		my $localAST = Context_get($context, $name);
		return AST::ERROR("VARIABLE $name NON DEFINIE") if(!defined $localAST);
		return MakeSUB($localAST)->($context);
	}
}

sub MakeSUB_AFFICHE{
	my $AST = shift;
	return sub{
		my $context = shift;
		my $expression = $AST->[1];
		my $valeur = MakeSUB($expression)->($context);
		return $valeur if(AST::EstUneERREUR($valeur));
		#ATTENTION il faut verifier les type !!!!
		if(scalar(@$valeur) == 1){
			if(AST::EstVOID($valeur)){
				print "\n";
			}else{
				print $valeur->[0] . "\n";
			}
		}else{
			if(AST::EstTABLO($valeur)){
				affiche_TABLO($context, $valeur);
				print "\n";
			}else{
				print $valeur->[1] . "\n";
			}
		}
		return ['VOID'];
	}
}
sub affiche_TABLO{
	my $context = shift;
	my $tablo   = shift;

	print tab2String($context, $tablo);
	return;
}
sub tab2String{
	my $context = shift;
	my $tablo   = shift;

	my $tab     = $tablo->[2];
	my $longueur= scalar(@$tab);
	my $accu    = "[";
	
	for(my $i=0; $i<$longueur; $i++){
		my $valeur = MakeSUB($tab->[$i])->($context);
		if(scalar(@$valeur) == 1){
			if(AST::EstVOID($valeur)){
				$accu .= "[]";
			}else{
				$accu .= $valeur->[0];
			}
		}else{
			if(AST::EstTABLO($valeur)){
				$accu .= tab2String($context, $valeur);
			}else{
				if(AST::EstSTRING($valeur)){
					# On ajoute les " pour du texte
					$accu .= '"' . $valeur->[1] . '"';
				}else{
					$accu .= $valeur->[1];
				}
			}
		}
		$accu .= "," if($i<$longueur-1);
	}
	return $accu . "]";
}
sub MakeSUB_STRICTSUP{
	my $AST = shift;
	return sub{
		my $context = shift;
		my $AST_L = $AST->[1];
		my $AST_R = $AST->[2];
		my $lhs = MakeSUB($AST_L)->($context);
		return $lhs if(AST::EstUneERREUR($lhs));
		my $rhs = MakeSUB($AST_R)->($context);
		return $rhs if(AST::EstUneERREUR($rhs));
		return $lhs if(AST::EstNOTHING($rhs));
		#ATTENTION il faut verifier que les types soient valables !
		#return MakeAST_VRAI() if($lhs->[1] > $rhs->[1]);
		return AST::VRAI() if($lhs->[1] > $rhs->[1]);
		return AST::FAUX;
	}
}
sub MakeSUB_EQUALITE{
	my $AST = shift;
	return sub{
		my $context = shift;
		my $AST_L = $AST->[1];
		my $AST_R = $AST->[2];
		my $lhs = MakeSUB($AST_L)->($context);
		return $lhs if(AST::EstUneERREUR($lhs));
		my $rhs = MakeSUB($AST_R)->($context);
		return $rhs if(AST::EstUneERREUR($rhs));
		return $lhs if(AST::EstNOTHING($rhs));
		#ATTENTION il faut verifier que les types soient valables !
		return AST::VRAI() if(AST::EstVOID($lhs) && AST::EstVOID($rhs));
		return AST::VRAI() if(AST::EstVOID($lhs) && AST::EstSTRING($rhs) && $rhs->[1] eq '');
		return AST::VRAI() if(AST::EstVOID($rhs) && AST::EstSTRING($lhs) && $lhs->[1] eq '');
		return AST::FAUX if(AST::EstVOID($lhs) || AST::EstVOID($rhs));
		return AST::VRAI() if($lhs->[1] eq $rhs->[1]);
		return AST::FAUX;
	}
}
sub MakeSUB_CONDITION{
	my $AST = shift;
	return sub{
		my $context = shift;
		my $condition = $AST->[1];
		my $alors     = $AST->[2];
		my $sinon     = $AST->[3];
		my $si = MakeSUB($condition)->($context);
		return $si if(AST::EstUneERREUR($si));
		if(AST::EstVRAI($si)){
			return MakeSUB($alors)->($context);
		}else{
			unless(AST::EstNULL($sinon)){
				return MakeSUB($sinon)->($context);
			}else{
				return ['VOID'];
			}
		}
	}
}
sub MakeSUB_TANTQUE{
	my $AST = shift;
	return sub{
		my $context      = shift;
		my $condition    = $AST->[1];
		my $instructions = $AST->[2];
		my $resultat = ['VOID'];
		while(1){
			my $validite = MakeSUB($condition)->($context);
			return $validite if(AST::EstUneERREUR($validite));
			if(AST::EstVRAI($validite)){
				$resultat = MakeSUB($instructions)->($context);
			}else{
				return $resultat;
			}
		}
	}
}

# Execute une action sur chaque
# Element de la liste
sub LIST_ACTION{
	my $list   = shift;
	my $action = shift;
	my $next   = MakeIterator_LIST($list);
	while(1){
		my $element = $next->();
		last if(AST::EstNULL($element));
		$action->($element);
	}
}
#Cree un Iterateur pour differentes LIST
#Une LIST peut aussi etre un AST NULL
sub MakeIterator_LIST{
	my $liste = shift;
	return sub{
		return $liste if(AST::EstNULL($liste));
		return AST::ERROR($liste->[0]." n'est pas une liste !") if($liste->[0] !~ /^LIST_/);
		my $element = $liste->[1];
		$liste = $liste->[2];
		return $element;
	}
}
sub MakeSUB_LIST_INSTRUCTIONS{
	my $AST = shift;
	my $Instruction = $AST->[1];# l'instruction a executer
	my $CDR = $AST->[2];# les instructions suivantes
	return sub{
		my $context = shift;
		my $retour = MakeSUB($Instruction)->($context);

		# Si c'est une erreur, on coupe le flux du programme
		return $retour if(AST::EstUneERREUR($retour));

		return $retour if(AST::EstNULL($CDR));#il n'y a pas d'instructions suivantes
		return MakeSUB($CDR)->($context);#on execute l'instruction suivante
	}
}

sub MakeSUB_FUNCASSIGN{
	my $AST        = shift;
	my $defunc     = $AST->[1];
	my $code       = $AST->[2];
	my $funcName   = $defunc->[1]->[1];
	my $parameters = $defunc->[2];
	return sub{
		my $context = shift;
		Context_set($context, $funcName, ['LAMBDA',$parameters,$code,$context]);
		return ['VOID'];
	}
}
sub MakeSUB_DEFLAMBDA{
	my $AST = shift;
	my $parameters = $AST->[1];
	my $code   = $AST->[2];
	return sub{
		my $context = shift;
		return ['LAMBDA',$parameters,$code,$context];
	}
}
#Pour l'instant transforme un defrange en tableau
#uterieurement il faudra utiliser des listes en
#lazy evaluation afin d'avoir des ranges infinis
sub MakeSUB_DEFRANGE{
	my $AST     = shift;
	my $premier = $AST->[1];
	my $second  = $AST->[2];
	return sub{
		my $context = shift;
		my $tab = [];
		my $val1 = MakeSUB($premier)->($context);
		return $val1 if(AST::EstUneERREUR($val1));
		return AST::ERROR("Le premier parametre de la definition de la range n'est pas numerique !") if(!AST::EstNUMERIC($val1));
		my $val2 = MakeSUB($second)->($context);
		return $val2 if(AST::EstUneERREUR($val2));
		return AST::ERROR("Le second parametre de la definition de la range n'est pas numerique !") if(!AST::EstNUMERIC($val2));
		my $debut = $val1->[1];
		my $fin   = $val2->[1];
		if($debut <= $fin){
			for(my $i=$debut;$i<= $fin;$i++){
				push(@$tab, AST::NUMERIC($i));
			}
		}else{
			for(my $i=$debut;$i>= $fin;$i--){
				push(@$tab, AST::NUMERIC($i));
			}
		}
		return AST::MakeAST_TABLO($tab);
	}
}
sub MakeSUB_DEFTABLO{
	my $AST = shift;
	my $parameters = $AST->[1];
	return sub{
		my $context = shift;
		my $tab = [];
		return ['VOID'] if(AST::EstVOID($parameters));
		my $nextArgument = MakeIterator_LIST($parameters);
		while(1){
			my $currentArgument = $nextArgument->();
			last if(AST::EstNULL($currentArgument));
			
			# On calcul les arguments comme des gloutons
			my $valeur = MakeSUB($currentArgument)->($context);
			return $valeur if(AST::EstUneERREUR($valeur));
			push(@$tab, $valeur);
		}
		# Rappel la taille de @$tab est scalar(@$tab) !!!
		return AST::TABLO($tab);
	}
}

sub MakeSUB_TABLO{
	#Un TABLO ne peut etre execute
	#que a travers un FUNC
	my $AST = shift;
	return sub{
		return $AST;
	}
}

sub internal_EFFACE{
	if($GLOBAL_MODE eq 'ECRAN'){
		clear();
		refresh();
	}else{
		if($GLOBAL_MODE eq 'LIGNE'){
			do_mode_ECRAN();
			clear();
			refresh();
			do_mode_LIGNE();
		}
	}
	return ['VOID'];
}

sub internal_GETMAXX{
	return AST::NUMERIC(getmaxx());
}

sub internal_GETMAXY{
	return AST::NUMERIC(getmaxy());
}

sub internal_POS{
	my $context = shift;
	my $valeur = shift;
	my $valeur2= shift;
	return AST::ERROR("Le premier parametre de la fonction 'pos' n'est pas numerique !") if(!AST::EstNUMERIC($valeur));
	return AST::ERROR("Le second parametre de la fonction 'pos' n'est pas numerique !") if(!AST::EstNUMERIC($valeur2));
	my $x = $valeur->[1];
	my $y = $valeur2->[1];
	move($y,$x);
	return ['VOID'];
}

sub internal_RAFRAICHIS{
	refresh();
	return ['VOID'];
}

sub internal_MODE{
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas du texte, pour fonction 'mode'!") if(!AST::EstSTRING($valeur));
	my $texte = $valeur->[1];
	if($texte eq 'LIGNE'){
#		do_mode_LIGNE();
		return ['VOID'];
	}
	if($texte eq 'ECRAN'){
#		do_mode_ECRAN();
		return ['VOID'];
	}
	if($texte eq 'TAMPON'){
		do_mode_TAMPON();
#		return ['VOID'];
	}
	return AST::ERROR("Mode $texte inconnu !");
}

sub do_mode_LIGNE{
	$GLOBAL_MODE='LIGNE';
#	echo();
#	nocbreak();
#	curs_set(1);
#	endwin;
}
sub do_mode_ECRAN{
	$GLOBAL_MODE='ECRAN';
#	initscr;
#	noecho();
#	cbreak();
#	curs_set(0);
}
sub do_mode_TAMPON{
#	do_mode_ECRAN();
	$GLOBAL_MODE='TAMPON';
}

# Appel une fonction interne,
# une fonction en perl
sub Call_Internal{
	my $context = shift;
	my $internalFunction = shift;
	my $arguments = shift;
	my @parameters = ();
	my $nextArgument = MakeIterator_LIST($arguments);
	my $hasElement = 1;
	while($hasElement){
		my $element = $nextArgument->();
		if(!AST::EstNULL($element)){
			# ATTENTION:
			# parametres gloutons pour l'instant
			my $val = MakeSUB($element)->($context);
			return $val if(AST::EstUneERREUR($val));
			push(@parameters, $val);
		}else{
			$hasElement = 0;
		}
	}
	my $iFunc = AST::getINTERNALFUNC($internalFunction);
	$iFunc->($context,@parameters);
}
sub internal_ROUND{
	my $context = shift;
	my $valeur  = shift;
	return AST::ERROR("N'est pas numerique, pour arrondi !". $valeur->[1]) if(!AST::EstNUMERIC($valeur));
	return AST::NUMERIC(sprintf("%.4f", $valeur->[1]));
}

sub internal_ARRONDIS{
	my $context = shift;
	my $valeur  = shift;
	return AST::ERROR("N'est pas numerique, pour arrondi !") if(!AST::EstNUMERIC($valeur));
	return AST::NUMERIC(sprintf("%.0f", $valeur->[1]));
}

sub internal_HASARD{ 
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas numerique, pour hasard !") if(!AST::EstNUMERIC($valeur));
	return AST::NUMERIC(rand($valeur->[1]));
}

sub internal_LENGTH{
	my $context = shift;
	my $valeur = shift; 
	#La longueur d'un tablo est scalar(@tablo)
	if(AST::EstTABLO($valeur)){
		my $tab= $valeur->[2];
		my $long = scalar(@$tab);
		return AST::NUMERIC($long);
	}
	if(AST::EstVOID($valeur)){
		return AST::NUMERIC(0);
	}
	return AST::ERROR("N'est pas du texte !".$valeur->[0]." ".$valeur->[1]) if(!(AST::EstSTRING($valeur) || AST::EstNUMERIC($valeur)));
	my $val = $valeur->[1];
	$val = "$val" if(AST::EstNUMERIC($valeur));
	return AST::NUMERIC(length($val));
}

sub internal_RESTE{
	my $context = shift;
	my $valeur1 = shift;
	return $valeur1 if(AST::EstUneERREUR($valeur1));
	my $valeur2 = shift;
	return $valeur2 if(AST::EstUneERREUR($valeur2));
	return AST::NUMERIC($valeur1->[1] % $valeur2->[1]);
}

sub internal_POW{
	my $context = shift;
	my $valeur1 = shift;
	return $valeur1 if(AST::EstUneERREUR($valeur1));
	my $valeur2 = shift;
	return $valeur2 if(AST::EstUneERREUR($valeur1));
	return AST::NUMERIC(($valeur1->[1]) ** $valeur2->[1]);
}

sub internal_SQRT{
	my $context = shift;
	my $valeur1 = shift;
	return $valeur1 if(AST::EstUneERREUR($valeur1));
	return AST::NUMERIC(sqrt($valeur1->[1]));
}

sub internal_PRINT{
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas printable !") if(!(AST::EstSTRING($valeur) || AST::EstNUMERIC($valeur)));
	if($GLOBAL_MODE eq 'LIGNE'){
		print $valeur->[1] ;
	}else{
		printw( $valeur->[1]);
		refresh() if($GLOBAL_MODE eq 'ECRAN');
	}
	return ['VOID'];
}

sub internal_PAUSE{
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas numerique !") if(!AST::EstNUMERIC($valeur));
	Time::HiRes::sleep($valeur->[1]);
	return ['VOID'];
}

sub internal_EXECUTE{
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas executable !") if(!AST::EstSTRING($valeur));
	my $executable=$valeur->[1];
	my $retour=`$executable`;
	return AST::STRING($retour);
}

sub internal_PEEK{
	my $context = shift;
	my $valeur = shift;
	return AST::ERROR("N'est pas numerique !") if(!AST::EstNUMERIC($valeur));
	my $adresse=$valeur->[1];
	my $executable = "dir ";
	my $retour=`$executable $adresse`;
	return MakeVRAI() if($retour == 1);
	return MakeFAUX()  if($retour == 0);
	return AST::ERROR("Valeur non booleenne !");
}

sub internal_POKE{
	my $context = shift;
	my $adresse = shift;
	return AST::ERROR("Adresse n'est pas numerique !") if(!AST::EstNUMERIC($adresse));
	my $bit = shift;
	return AST::ERROR("Bit n'est pas digital !") if(!AST::EstBOOLEAN($bit));
	my $executable='gpio -1 write';
	my $addr = $adresse->[1];
	my $binaryDigit;
	if(AST::EstVRAI($bit)){
		$binaryDigit=1;
	}else{
		$binaryDigit=0;
	}
	gpioModeWrite($addr);
	my $retour=`$executable $addr $binaryDigit`;
	return AST::STRING($retour);
}

sub gpioModeWrite{
	my $gpioPIN = shift;
	#Verifions si le
	`gpio -1 mode $gpioPIN out ` if($GLOBAL_GPIO_PIN[$gpioPIN-1] ne 'out');
	$GLOBAL_GPIO_PIN[$gpioPIN-1]= 'out'; 
}
sub gpioModeRead{
	my $gpioPIN = shift;
	#Verifions ...
	`gpio -1 mode $gpioPIN in ` if($GLOBAL_GPIO_PIN[$gpioPIN-1] ne 'in');
	$GLOBAL_GPIO_PIN[$gpioPIN-1]= 'in'; 
}

sub bracketOnTablo{
	my $context =  shift;
	my $tablo= shift;
	my $arguments= shift;
	my $nextArgument = MakeIterator_LIST($arguments);
	my $currentArgument = $nextArgument->();
	my $valeur = MakeSUB($currentArgument)->($context);

	return AST::ERROR("N'est ni du texte, ni numerique !".$valeur->[0]." ".$valeur->[1]) if(!(AST::EstSTRING($valeur) || AST::EstNUMERIC($valeur)));

	my $val = $valeur->[1];

	return $tablo->[1]->($valeur);
}
sub bracketOnString{
	my $context = shift;
	my $phrase = shift;
	my $arguments = shift;
	my $nextArgument = MakeIterator_LIST($arguments);
	my $currentArgument = $nextArgument->();
	my $valeur = MakeSUB($currentArgument)->($context);

	return AST::ERROR("N'est ni du texte, ni numerique !".$valeur->[0]." ".$valeur->[1]) if(!(AST::EstSTRING($valeur) || AST::EstNUMERIC($valeur)));

	my $val = $valeur->[1];

	if(AST::EstNUMERIC($valeur)){
		return AST::ERROR("$val > longueur de ". $phrase->[1]) if($val>length($phrase->[1]));
		return AST::STRING(substr($phrase->[1],$val,1))
	}
	if($val eq 'maillon'){
		return AST::STRING(substr($phrase->[1],0,1));
	}
	else{
		if($val eq 'suite'){
			return ['VOID'] if(substr($phrase->[1],1) eq '');
			return AST::STRING(substr($phrase->[1],1));
		}
	}
	return AST::ERROR("Methode " . $val . " inconnu pour du texte !");
}
sub bracketOnNumeric{
	my $context =  shift;
	my $numeric =  shift;
	my $arguments= shift;
	my $nextArgument = MakeIterator_LIST($arguments);
	my $currentArgument = $nextArgument->();
	my $valeur = MakeSUB($currentArgument)->($context);

	my $val = $valeur->[1];

	my $ast = ['MULT', $numeric, $valeur];
	return MakeSUB($ast)->($context);
}
sub bracketOnLambda{
	my $context   = shift;
	my $lambda    = shift;
	my $arguments = shift;
	my $funcName  = shift;
	
	my $lambdaArgsList = $lambda->[1];
	my $code = $lambda->[2];
	my $lambdaContext = $lambda->[3];
	my $parentContext = $lambdaContext->[2];
	my $paramContext = Context_New();

	# On assigne chaque argument a celui
	# correspondant dans lambdaArgsList
	my $nextArgument = MakeIterator_LIST($arguments);
	my $nextLambdaArg= MakeIterator_LIST($lambdaArgsList);
	while(1){
		my $currentArgument = $nextArgument->();
		last if(AST::EstNULL($currentArgument));
		my $currentLambdaArg= $nextLambdaArg->();
		return AST::ERROR("La fonction ".$funcName." comporte moins d'arguments !") if(AST::EstNULL($currentLambdaArg));
		return AST::ERROR("L'identifiant " . $currentLambdaArg->[0]. " de la fonction " . $funcName . " n'est pas un identifiant !") if(!AST::EstID($currentLambdaArg));
		my $argName = $currentLambdaArg->[1];
		# On calcul les arguments comme des gloutons
		# pour ne pas se melanger les pinceaux entre
		# les arguments de la fonctions et les arguments
		# de la closure (la fermeture quoi !)
		my $valeur = MakeSUB($currentArgument)->($context);
		print "DEBUG: pour $argName, " . Dumper($valeur) . "\n" if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));
		return $valeur if(AST::EstUneERREUR($valeur));
		Context_set($paramContext, $argName, $valeur);
	}
	Context_setParent($paramContext, $lambdaContext);
	my $retour = MakeSUB($code)->($paramContext);
	print "Resultat de $funcName: " . Dumper($retour) if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));;
	return $retour;
}
sub MakeSUB_BRACKET{
	my $AST      = shift;
	my $funcExpr = $AST->[1];
	my $funcName = "'indefini'"; 
	my $arguments= $AST->[2];
	return sub{
		my $context = shift;
		my $lambda;

		if(AST::EstID($funcExpr)){
			$funcName = $AST->[1]->[1];

			$lambda = Context_get($context,$funcName);
			return AST::ERROR("FONCTION $funcName NON DEFINIE") if(!defined $lambda);

			if(AST::EstID($lambda)){
				#A surveiller !!!!
				#Necessaire lorsque l'on utilise un '=' et non '<-'
				#On doit determiner de quel type est lambda
				$lambda = MakeSUB($lambda)->($context);
			}

		}else{
			$lambda = MakeSUB($funcExpr )->($context);

			if(AST::EstID($lambda)){
				#Cas du deflambda !
				$lambda = MakeSUB($lambda)->($context);
			}
		}

		return bracketOnTablo($context, MakeSUB($lambda)->($context), $arguments) if(AST::EstDEFTABLO($lambda));
		return bracketOnString($context, MakeSUB($lambda)->($context), $arguments) if(AST::EstSTRINGQUOTE($lambda));

		return bracketOnString($context,$lambda, $arguments) if(AST::EstSTRING($lambda));
		return bracketOnTablo($context,$lambda, $arguments) if(AST::EstTABLO($lambda));
		return bracketOnNumeric($context,$lambda, $arguments) if(AST::EstNUMERIC($lambda));

		return Call_Internal($context,$lambda, $arguments) if(AST::EstINTERNALFUNC($lambda));

		return bracketOnLambda($context,$lambda, $arguments, $funcName) if(AST::EstLAMBDA($lambda));

		if(!AST::EstLAMBDA($lambda)){
			my $err = Dumper($lambda);
			return AST::ERROR("n'est pas une fonction: $err");
		}

		return ['VOID'];


		print "DEBUG: Lambda $funcName\n" if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));

		my $lambdaArgsList = $lambda->[1];
		my $code = $lambda->[2];
		my $lambdaContext = $lambda->[3];
		my $parentContext = $lambdaContext->[2];
		my $paramContext = Context_New();

		# On assigne chaque argument a celui
		# correspondant dans lambdaArgsList
		my $nextArgument = MakeIterator_LIST($arguments);
		my $nextLambdaArg= MakeIterator_LIST($lambdaArgsList);
		while(1){
			my $currentArgument = $nextArgument->();
			last if(AST::EstNULL($currentArgument));
			my $currentLambdaArg= $nextLambdaArg->();
			return AST::ERROR("La fonction ".$funcName." comporte moins d'arguments !") if(AST::EstNULL($currentLambdaArg));
			return AST::ERROR("L'identifiant " . $currentLambdaArg->[0]. " de la fonction " . $funcName . " n'est pas un identifiant !") if(!AST::EstID($currentLambdaArg));
			my $argName = $currentLambdaArg->[1];
			# On calcul les arguments comme des gloutons
			# pour ne pas se melanger les pinceaux entre
			# les arguments de la fonctions et les arguments
			# de la closure (la fermeture quoi !)
			my $valeur = MakeSUB($currentArgument)->($context);
			print "DEBUG: pour $argName, " . Dumper($valeur) . "\n" if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));
			return $valeur if(AST::EstUneERREUR($valeur));
			Context_set($paramContext, $argName, $valeur);
		}
		Context_setParent($paramContext, $lambdaContext);
		my $retour = MakeSUB($code)->($paramContext);
		print "Resultat de $funcName: " . Dumper($retour) if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));;
		return $retour;
	}
}
sub MakeSUB_LAMBDA{
	#Un LAMBDA ne peut etre execute
	#que a travers un FUNC
	my $AST = shift;
	return sub{
		return $AST;
	}
}
sub MakeSUB_POURCONTEXT{
	my $AST = shift;
	my $allocates   = $AST->[1];
	my $instructions= $AST->[2];
	return sub{
		my $context = shift;
		my $newContext = Context_New();
		my $nextAllocate = MakeIterator_LIST($allocates);
		while(1){
			my $currentAllocate = $nextAllocate->();
			last if(AST::EstNULL($currentAllocate));
			my $id = $currentAllocate->[1];
			my $idName = $id->[1];
			my $value = $currentAllocate->[2];
			my $valeur = MakeSUB($value)->($context);
			return $valeur if(AST::EstUneERREUR($valeur));
			Context_set($newContext, $idName, $valeur);
		}
		Context_setParent($newContext, $context);
		return MakeSUB($instructions)->($newContext);
	}
}
sub MakeSUB_BOUCLEPOUR{
	my $AST = shift;
	my $Identifiant = $AST->[1];
	my $firstValue  = $AST->[2];
	my $lastValue   = $AST->[3];
	my $increment   = $AST->[4];
	my $instructions= $AST->[5];
	
	return sub{
		my $context = shift;
		
		my $first = MakeSUB($firstValue)->($context);
		return $first if(AST::EstUneERREUR($first));
		return AST::ERROR("Valeur d'initialisation de boucle 'pour' n'est pas Numerique") if(!AST::EstNUMERIC($first));
		my $last  = MakeSUB($lastValue)->($context);
		return $last if(AST::EstUneERREUR($last));
		return AST::ERROR("Valeur de fin de boucle 'pour' n'est pas Numerique") if(!AST::EstNUMERIC($last));
		my $inc = MakeSUB($increment)->($context);
		return $inc if(AST::EstUneERREUR($inc));
		return AST::ERROR("Valeur d'increment de boucle 'pour' n'est pas Numerique") if(!AST::EstNUMERIC($inc));
		my $var_name = $Identifiant->[1];
		my $valeur = $first->[1];
		my $instruct = MakeSUB($instructions);
		my $result;
		my $newContext = Context_New();
		Context_set($newContext,$var_name,AST::NUMERIC($valeur));
		Context_setParent($newContext, $context);
		while($valeur <= $last->[1]){
			Context_set($newContext,$var_name,AST::NUMERIC($valeur));
			$result = $instruct->($newContext);
			return $result if(AST::EstUneERREUR($result));
			#On incremente valeur (qui a pu etre modifiee
			#par le programme)
			$valeur = Context_get($newContext,$var_name)->[1];
			$valeur += $inc->[1];
			Context_set($newContext,$var_name,AST::NUMERIC($valeur));
		}
		return $result;
	}
}
sub MakeSUB_POURCHAQUE{
	my $AST = shift;
	my $Identifiant = $AST->[1];
	my $instructionliste = $AST->[2];
	my $instructions= $AST->[3];
	
	return sub{
		my $context = shift;
		my $var_name = $Identifiant->[1];
		my $liste = MakeSUB($instructionliste)->($context);
		my $valeur = ['VOID'];
		my $instruct = MakeSUB($instructions);
		my $result;
		my $newContext = Context_New();
		Context_set($newContext,$var_name,$valeur);
		Context_setParent($newContext, $context);
		my $onContinue = 1;
		while($onContinue){
			$valeur = MakeSUB_BRACKET(['',$liste,['LIST_GENERIC',['NUMERIC',0],['NULL']]])->($context);
			return $valeur if(AST::EstUneERREUR($valeur ));
			Context_set($newContext,$var_name,$valeur);
			$result = $instruct->($newContext);
			return $result if(AST::EstUneERREUR($result));
			my $suite = MakeSUB_BRACKET(['',$liste,['LIST_GENERIC',['STRING','suite'],['NULL']]])->($context);
			return $suite if(AST::EstUneERREUR($suite));
			$liste = $suite;
			$onContinue = 0 if(AST::EstVOID($suite));
		}
		return $result;
	}
}

sub addInternalFunc{
	my $context= shift;
	my @funcTable = @_;
	foreach my $f (@funcTable){
		# funcName: f->[0]; funcBody: f->[1]
		Context_set($context, $f->[0], $f->[1]);
	}
}

sub installInternalFunc{
	my $context = shift;
	addInternalFunc($context,
		['round', AST::INTERNALFUNC(\&internal_ROUND)],
		['entier', AST::INTERNALFUNC(\&internal_ARRONDIS)],
		['hasard', AST::INTERNALFUNC(\&internal_HASARD  )],
		['longueur', AST::INTERNALFUNC(\&internal_LENGTH)],
		['ecris', AST::INTERNALFUNC(\&internal_PRINT)],
		['reste', AST::INTERNALFUNC(\&internal_RESTE)],
		['pow', AST::INTERNALFUNC(\&internal_POW)],
		['sqrt', AST::INTERNALFUNC(\&internal_SQRT)],
		['pause', AST::INTERNALFUNC(\&internal_PAUSE)],
		['execute', AST::INTERNALFUNC(\&internal_EXECUTE)],
		['peek', AST::INTERNALFUNC(\&internal_PEEK)],
		['poke', AST::INTERNALFUNC(\&internal_POKE)],
		['mode', AST::INTERNALFUNC(\&internal_MODE)],
		['pos' , AST::INTERNALFUNC(\&internal_POS)],
		['rafraichis', AST::INTERNALFUNC(\&internal_RAFRAICHIS)],
		['efface' , AST::INTERNALFUNC(\&internal_EFFACE)],
		['max_X' , AST::INTERNALFUNC(\&internal_MAXX)],
		['max_Y' , AST::INTERNALFUNC(\&internal_MAXY)],
	);
}


sub load{
	my $context = shift;
	my $file= (shift || "code");
	my $file2 = $file . ".cmp";
	$file .= ".bas";
	if(-e $file){
		say "loading $file";
		# Si le fichier compil existe et sa date de modification
		# est supperieure a celle du fichier source
		if(-e $file2 && ((stat($file))[9] < (stat($file2))[9])){
			#On lis le fichier compil pour l'ast
			open(my $F2, '<', $file2);
			my $txt = <$F2>;
			close($F2);
			my $ast = Compile::String2AST($txt);
			say Dumper($ast);
			TraiteAST($ast, $context);
			return;
		}else{
			open(my $F, '<', $file);
			my $fichier = "";
			while(my $ligne = <$F>){
				#On ignore les commemtaire (commencent par #)
				#ainsi que les lignes vides
				#chomp($ligne);
				if($ligne !~ /^\s*#/ && ($ligne !~ /^\s*$/)){
					#On ajoute ; en fin de ligne
					#sauf si elle finit par la REGEX
					$ligne .=';' if($ligne !~ /(\,|:|\{|=|<-|;|\(|si|alors|sinon|jusqu'a)\s*$/);
					#On enleve le ; en fin de la precedente ligne
					#si la nouvelle ligne commence par la REGEX
					$fichier =~ s/(.*);$/$1/ if($ligne =~ /^\s*(\,|:|\}|=|<-|;|\)|alors|sinon|suivant|fin|jusqu'a)/);
					$fichier .= $ligne;
					#chomp($fichier);
				}
			}
			print $fichier . "\n";
			my $ast = ligne2AST($fichier, $context);
			say Dumper($ast);
			my $line= Compile::AST2String($ast);
			open(my $F3, '>', $file2);
			print $F3 $line;
			close($F3);
			say $line;
			TraiteAST($ast, $context);
			#TraiteLigne($fichier, $context);
		}
	}else{
		say "Fichier $file inexistant";
	}
}

sub TraiteAST{
	my $ast = shift;
	my $context = shift;
	my $sub = MakeSUB($ast);
	my $resultatSUB = $sub->($context);
	if(AST::EstUneERREUR($resultatSUB)){
		print $resultatSUB->[0] . ": " . $resultatSUB->[1] . "\n";
	}else{
		if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON'))){
			say "Resultat:";
			print Dumper($resultatSUB);
		}else{
			#ATTENTION, gros hack !!!
			MakeSUB_AFFICHE(['AFFICHE',$resultatSUB])->($context) unless(AST::EstVOID($resultatSUB));
		}
	}
}
sub ligne2AST{
	my $input = shift;
	my $context = shift;
	chomp($input);
	return ['VOID'] if($input =~ /^\s*$/);
	return ['VOID'] if($input =~ /^\s*\#/ );
	#my $ast = $parser->startrule(\$input);
	my $ast = ParserRecdescent::getAST(\$input);
	$input =~ s/\s*$//;
	return AST::ERROR("Erreur de syntaxe au niveau de **$input**") if($input ne "" && $input !~ /\s*;\s*/);
	$ast = RemoveNOTHING($ast, 0);
	print Dumper($ast) if(defined Context_get($context,'TRON') && AST::EstVRAI(Context_get($context,'TRON')));
	return $ast;
}

sub TraiteLigne{
	my $input   = shift;
	my $context = shift;

	return TraiteAST(ligne2AST($input,$context), $context);
}

my $context = Context_New();
my $term = Term::ReadLine->new('KSCRIPT');
my $prompt = "(0)> ";
my $OUT = $term->OUT || \*STDOUT;
my @in = ();
my $ind = 0;
my $attribs = $term->Attribs;
$attribs->{completion_function} = sub{
	my ($text, $line, $start) = @_;
	return listBASFiles() if($line =~ /load\s+$text$/);
	return qw(load pour chaque si sinon fin ciao exit affiche suivant jusqu'a);
};

# Installation des fonctions internes:
installInternalFunc($context);

sub listBASFiles{
	my @files = <*.bas>;
	my @fichiers =();
	foreach my $f (@files){
		$f =~ s/(.*)\.bas/$1/;
		push @fichiers, $f;
	}
	return @files;
}

while( defined(my $input = $term->readline($prompt))){
	chomp($input);
	exit if($input =~ /^\s*(bye|ciao|quit|exit)\s*$/);
	if($input =~ /^\s*(load)\s+(.*)$/) {
		my $file= $2;
		$file =~ s/(.*?)\s*$/$1/;
		load($context,$file)
	}
	else{ TraiteLigne($input, $context)};
	$term->addhistory($input) if $input !~ /\S/;
}
