package Compile;
use Data::Dumper;
use strict;
use warnings;
use 5.010;

my @expressions = (
    ['BOUCLEPOUR',5,'1'],['CONDITION',3,'2'],['POURCHAQUE',3,'3'],
    ['OR',2,'4'],['AND',2,'5'],['XOR',2,'6'],['ADD',2,'7'],['SUBS',2,'8'],['MULT',2,'9'],
    ['DIV',2,'A'],['CONCATENE',2,'B'],['ASSIGN',2,'C'],['AFFECT',2,'D'],['TANTQUE',2,'E'],
    ['POURCONTEXT',2,'F'],['LIST_INSTRUCTIONS',2,'G'],['EQUALITE',2,'H'],
    ['STRICTSUP',2,'I'],['FUNCASSIGN',2,'J'],['DEFLAMBDA',2,'K'],
    ['DEFRANGE',2,'L'],['BRACKET',2,'M'],
    ['AFFICHE',1,'N'],['INSPECT',1,'O'],['DEFTABLO',1,'P'],
    ['VOID',0,'Q'],['NOTHING',0,'R'],['INPUT',0,'S'],['NULL',0,'Z'],
    ['NOT',1,'a'],['DEFUNC',2,'b'],['LIST_IDENTIFIERS',2,'c'],['LIST_ARGUMENTS',2,'d']);

sub AST2String{
    my $AST = shift;
    return MakeSUB($AST)->();
}
sub String2AST{
    my $txt = shift;
    my $index = 0;
    my $getChar = sub{
        $index++;
        return substr($txt,$index-1,1);
    };
    
    return getAST($getChar);
}

sub estBasicType{
    my $type = shift;
    return 1 if($type eq 'U' || $type eq 'V' || $type eq 'W');
    return 0;
}

sub booleanValue{
    my $bool = shift;
    return 'VRAI' if($bool eq 'X');
    return 'FAUX';
}

#Prend des caractere jusqu'au guillemet
sub getStringValue{
    my $getChar = shift;
    my $ch = $getChar->();
    return $ch . getStringValue($getChar) if($ch ne '"');
    return '';
}

sub getBasicTypeAST{
    my $getChar = shift;
    my $type    = shift;
    #my @tab     = (['U','NUMERIC'],['V','STRINGQUOTE'],['W','ID']);
    my %tab     = ('U','NUMERIC','V','STRINGQUOTE','W','ID');
    my $t = $tab{$type};
    return [$t, getStringValue($getChar)];
}

sub getAST{
    my $getChar = shift;
    my $type = $getChar->();

    #Test Boolean
    if($type eq 'T'){
        return ['BOOLEAN', booleanValue($getChar->())];
    }

    #Test Basic Type
    if(estBasicType($type)){
        #On zappe les premiers guillemets
        $getChar->();
        return getBasicTypeAST($getChar, $type);
    }
    
    #Tous les autres type d'AST
    foreach my $expression (@expressions){
        if($type eq $expression->[2]){
            my $ast = [$expression->[0]];

            # Test si AST unitaire
            return $ast if($expression->[1] == 0);

            foreach my $i (1..$expression->[1]){
                my $tmpAST = getAST($getChar);
                push @$ast, $tmpAST;
                #print Dumper($ast);
            }
            return $ast;
        }
    }

}

sub MakeSUB{
    my $AST = shift;

    if(ref($AST) ne 'ARRAY'){
        print "DEBUG: dans MakeSUB, AST n'est pas un tableau mais ##". ref($AST) ."##\n";
	print Dumper($AST);
	print "####\n";
	$AST = ['VOID'];
	die "Arghh !!!";
    }

    my @expressions = (['BOUCLEPOUR',5,'1'],['CONDITION',3,'2'],['POURCHAQUE',3,'3'],
        ['OR',2,'4'],['AND',2,'5'],['XOR',2,'6'],['ADD',2,'7'],['SUBS',2,'8'],['MULT',2,'9'],
        ['DIV',2,'A'],['CONCATENE',2,'B'],['ASSIGN',2,'C'],['AFFECT',2,'D'],['TANTQUE',2,'E'],
        ['POURCONTEXT',2,'F'],['LIST_INSTRUCTIONS',2,'G'],['EQUALITE',2,'H'],
        ['STRICTSUP',2,'I'],['FUNCASSIGN',2,'J'],['DEFLAMBDA',2,'K'],
        ['DEFRANGE',2,'L'],['BRACKET',2,'M'],
        ['AFFICHE',1,'N'],['INSPECT',1,'O'],['DEFTABLO',1,'P'],
        ['VOID',0,'Q'],['NOTHING',0,'R'],['INPUT',0,'S'],['NULL',0,'Z'],
	['NOT',1,'a'],['DEFUNC',2,'b'],['LIST_IDENTIFIERS',2,'c'],['LIST_ARGUMENTS',2,'d']);

    foreach my $exp (@expressions){
        if($AST->[0] eq $exp->[0]){
            return MakeSUB_ARITY($exp->[1],$exp->[2], $AST);
        }
    }




    foreach my $nom (['BOOLEAN','T'],['NUMERIC','U'],['STRINGQUOTE','V'],['ID','W']){
        if($AST->[0] eq $nom->[0]){
            return MakeSUB_BASICTYPE($nom->[0], $nom->[1], $AST);
            last;
        }
    }

    print "DEBUG: fin de MakeSUB pour\n";
    print Dumper($AST);
    die "ARGHH!";
#	return MakeSUB_STRING($AST) if($AST->[0] eq 'STRING');
#	#return MakeSUB_FUNC($AST) if($AST->[0] eq 'FUNC');
#	return MakeSUB_LAMBDA($AST) if($AST->[0] eq 'LAMBDA');
#	return MakeSUB_INTERNALFUNC($AST) if($AST->[0] eq 'INTERNALFUNC');
#	return MakeSUB_TABLO($AST) if($AST->[0] eq 'TABLO');
#	return MakeSUB_ERROR($AST) if($AST->[0] eq 'ERROR');
#	return MakeSUB_AST_ERROR($AST);
}

sub MakeSUB_BASICTYPE{
    my $type = shift;
    my $code = shift;
    my $AST  = shift;
    return sub{
        my $valeur = $AST->[1];
        #return "[$type " . '"' . $valeur . '"' . "]";
        if($type eq 'BOOLEAN'){
            if($valeur eq 'VRAI'){
                $valeur = 'X';
            }else{
                $valeur = 'Y';
            }
            return $code . $valeur;
        }
        else{
	    if($type eq 'STRINGQUOTE'){
		return "$code" . $valeur;
	    }else{
                return "$code" . '"' . $valeur . '"';
            }
        }
    }
}


sub MakeSUB_ARITY{
    my $arity = shift;
    my $code  = shift;
    my $AST   = shift;
    return sub{
        #my $text = "[" . $AST->[0];
	my $text = "$code";
            if($arity > 0){
            foreach my $i (1..$arity){
		my $subAST = $AST->[$i];
		if(ref($subAST) ne 'ARRAY'){
			print "****\n";
			print "DEBUG: N'est pas un tableau **" . ref($subAST) . "**\n";
			print Dumper($AST) . "\n";
			print "ERREUR pour index: $i\n";
			print Dumper($subAST) . "\n";
			print "****\n\n";
			die "Arghhhh !!!!";
		}else{
			#my $sub = MakeSUB($AST->[$i]);
			my $sub = MakeSUB($subAST);
			#if(ref(MakeSUB($AST->[$i])) eq 'CODE'){
			if(ref($sub) eq 'CODE'){
			    #$text .= MakeSUB($AST->[$i])->();
			    $text .= $sub->();
			}else{
			    #print "DEBUG: N'est pas une fonction: **" . MakeSUB($AST->[$i]) . "**\n";
			    print "DEBUG: N'est pas une fonction. REF=**" . ref($sub) . "**\n";
			    #print ' ' . MakeSUB($sub) . "**\n";
			    print Dumper($AST)."\n";
			    print "ERREUR pour l'index num: $i\n";
			    print Dumper($AST->[$i]) . "\n";
			    print "*********\n\n";
		    }
		}
            }
        }
        #$text .= ']';
        return $text;
    }
}

1;
