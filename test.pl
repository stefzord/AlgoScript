use strict;
use warnings;
use 5.010;
use Data::Dumper;
use Compile;

my $ast1= ['OR', ['BOOLEAN','FAUX'],['BOOLEAN','VRAI']];
my $ast2= ['CONCATENE',['BOOLEAN','VRAI'],['ID', 'a']];
my $ast3= ['CONCATENE',['BOOLEAN','VRAI'],['NUMERIC',3.14]];
my $ast4= ['ADD',['NUMERIC',5.6],['NUMERIC',3.14]];
my $ast5= ['CONCATENE',['STRINGQUOTE',"Coucou le Monde"],['NUMERIC',3.14]];
my $ast6= ['AFFICHE',['CONCATENE',['STRINGQUOTE',"Coucou le Monde"],['NUMERIC',3.14]]];
my $ast7= ['CONCATENE',['VOID'],['ID', 'a']];
my $ast8= ['CONCATENE',['INPUT'],['ID', 'a']];

foreach my $ast ($ast1, $ast2, $ast3, $ast4,
                $ast5, $ast6,$ast7, $ast8){
    print Compile::AST2String($ast);
    print "\n";
}

print "\nTEST AST:\n";
#my $tst = ['BOOLEAN', 'FAUX'];
my $tst = $ast6;
print Dumper($tst);
my $cmp = Compile::AST2String($tst);
print $cmp . "\n";
my $rsp = Compile::String2AST($cmp);
print Dumper($tst);
