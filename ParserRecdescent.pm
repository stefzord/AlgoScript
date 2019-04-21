package ParserRecdescent;
use Parse::RecDescent;
use 5.010;

$::RD_ERRORS = 1; #Parser dies when it encounters an error
$::RD_WARN   = 1; #Enable warnings - warn on unused rules &c.
$::RD_HINT   = 1; #Give out hints to help fix problems.
#$::RD_TRACE = 1; #Trace parser's behaviour


my $grammarNum = <<'_EOGRAMMARNUM_';

	############################################
	# ATTENTION: ne pas separer les expression #
	#   NUMERIQUES des expressions BOOLEANS    #
	############################################



	expression_boolean: equalite_boolean
	
	equalite_boolean : strictsup_expr equal_boolean
		{['EQUALITE', $item[1], $item[2]]}
	equal_boolean: '=' equalite_boolean
		{$item[2]}
		| # nothing
		{['NOTHING']}

	strictsup_expr: or_expr supstrict
		{['STRICTSUP', $item[1], $item[2]]}
	supstrict: '>' strictsup_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}
	
	or_expr : and_expr ou_expr
		{['OR', $item[1], $item[2]]}
	ou_expr: 'ou' or_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}


	#and_expr : add_expr et_expr
	#	{['AND', $item[1], $item[2]]}
	and_expr : concaten_expr et_expr
		{['AND', $item[1], $item[2]]}
	et_expr : 'et' and_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}


	
	#expression_numerique : add_expr
	expression_numerique : concaten_expr
	
	concaten_expr: add_expr concat_expr
		{['CONCATENE', $item[1], $item[2]]}
	concat_expr: '&' concaten_expr
		{$item[2]}
		| #nothing
		{['NOTHING']}

	add_expr : subs_expr plus_expr
		{['ADD',$item[1], $item[2]]}
	plus_expr: '+' add_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}


	subs_expr : div_expr moins_expr
			{['SUBS', $item[1], $item[2]]}
	moins_expr: '-' subs_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}


	div_expr : mult_expr divise_expr
			{['DIV', $item[1], $item[2]]}
	divise_expr: '/' div_expr
		{$item[2]}
		| # nothing
		{['NOTHING']}


	mult_expr : not_expr multiplie_expr
			{['MULT', $item[1], $item[2]]}
	multiplie_expr: '*' mult_expr
		{$item[2]}
		#| identifiant 
		#{$item[1]}
		| # nothing
		{['NOTHING']}

	not_expr : 'non' brack_expr
			{['NOT', $item[2]]}
#			| brack_expr
			| brack_operator

	brack_operator:
			brack_expr '(' ')'
			{['BRACKET', $item[1], ['NULL']]}
 			|brack_expr '(' arguments ')'
			{['BRACKET',$item[1],$item[3]]}
			|
			brack_expr

	brack_expr : DEFLAMBDA
			| defTablo
			|
			'(' expression_boolean')'
			{$item[2]}
			| code 
			| instructionnable 
			| VALEUR
	
	FAUX : "faux"
			{['BOOLEAN','FAUX']}
	VRAI : "vrai"
			{['BOOLEAN','VRAI']}

	RIEN : "rien"
			{['VOID']}

	INPUT : "lis"
			{['INPUT']}
			| "lire"
			{['INPUT']}

	VALEUR :  FAUX
		| VRAI
		|  RIEN
		| INPUT
		| NUMERIC
		| STRINGQUOTE
		| identifier
		#| LAMBDA

	NUMERIC : /(\+|\-)?\d+(\.(\d+))*/
			{['NUMERIC', $item[1]]}

	# ATTENTION: les guillemets sont
	# conservees lors du parsing !
	STRINGQUOTE : /"([^"\\]|\\["\\])*"/
			{['STRINGQUOTE', $item[1]]}

	identifier : #func |
				identifiant

	identifiant: /[a-z_][a-z0-9_\']*/i
			{['ID',$item[1]]} 

	DEFLAMBDA : '\(' params ')' code
			{['DEFLAMBDA', $item[2], $item[4]]}

#	func :	identifiant '(' ')'
#			{['FUNC', $item[1], ['NULL']]}
#			|identifiant '(' arguments ')' #Utilisation de fonction
#			{['FUNC', $item[1], $item[3]]}

	defunc : identifiant '(' params ')'    #Definition de fonction
			{['DEFUNC', $item[1], $item[3]]}

    defTablo: '[' arguments ']'
			{['DEFTABLO', $item[2]]}
			| '[' ']'
			{['DEFTABLO', ['VOID']]}
			| '[' expression  '..'  expression  ']'
			{['DEFRANGE', $item[2],$item[4]]}
	
	assign : defunc '=' instruction
		{['FUNCASSIGN', $item[1], $item[3]]}
		|	 identifier '=' instruction
		{['ASSIGN', $item[1], $item[3]]}

	affect : identifier '<-' instruction 
			{['AFFECT', $item[1], $item[3]]}
			| identifier 'prend' 'la' 'valeur' instruction
			{['AFFECT', $item[1], $item[5]]}

	ALLOCATE : assign
		|  affect

	arguments : instruction "," arguments 
					{['LIST_ARGUMENTS', $item[1], $item[3]]}
					| instruction
					{['LIST_ARGUMENTS', $item[1], ['NULL']]}

	params : identifiant "," params
			{['LIST_IDENTIFIERS', $item[1], $item[3]]}
			| identifier
			{['LIST_IDENTIFIERS', $item[1], ['NULL']]}
			| #nothing
			{['NULL']}

	affiche : 'affiche' instruction 
			{['AFFICHE', $item[2]]}

	affichable : expression | code

	inspect : 'inspecte' instruction
			{['INSPECT', $item[2]]}

	condition : 'si' expression 'alors' instructions 'sinon' instructions 'fin'
			{['CONDITION', $item[2], $item[4], $item[6]]}
			   |'si' expression 'alors' instructions 'fin'
			{['CONDITION', $item[2], $item[4],['NULL']]}

	bouclepour : 'pour' identifier '=' instruction "jusqu'a" instruction 'increment' instruction ':' instructions 'suivant'
			{['BOUCLEPOUR', $item[2], $item[4], $item[6], $item[8], $item[10]]}
				|'pour' identifier '=' instruction "jusqu'a" instruction ':' instructions 'suivant'
			{['BOUCLEPOUR', $item[2], $item[4], $item[6], ['NUMERIC','1'], $item[8]]}

	tantque : 'tant' 'que' expression ':' instructions 'fin'
			{['TANTQUE', $item[3], $item[5]]}
			| 'tant' 'que' expression  instructions 'fin'
			{['TANTQUE', $item[3], $item[4]]}

	pourchaque : 'pour' 'chaque' identifier 'de' instruction ':' instructions 'fin'
		{['POURCHAQUE',$item[3],$item[5],$item[7]]}
				|'pour' 'chaque' identifier 'de' instruction instructions 'fin'
				{['POURCHAQUE',$item[3],$item[5],$item[6]]}
				|'pour' 'chaque' identifier 'de' instruction instructions '.'
				{['POURCHAQUE',$item[3],$item[5],$item[6]]}


	allocates : ALLOCATE "," allocates
			{['LIST_ALLOCATES', $item[1], $item[3]]}
			| ALLOCATE 
			{['LIST_ALLOCATES', $item[1], ['NULL']]}

	pourcontext : 'pour' allocates ':' instructions 'fin'
			{['POURCONTEXT', $item[2], $item[4]]}
			|'pour' allocates instructions 'fin'
			{['POURCONTEXT', $item[2], $item[3]]}
			|'pour' allocates instructions '.'
			{['POURCONTEXT', $item[2], $item[3]]}
		
	code : '{' instructions '}'
		{$item[2]}

	instructionnable: condition | bouclepour | tantque | pourcontext | pourchaque
	
	expression : expression_boolean 

	instruction : inspect | condition | bouclepour | tantque | pourcontext| pourchaque | affiche| ALLOCATE | expression | code

	instructions : instruction SEPARATOR instructions
					{['LIST_INSTRUCTIONS', $item[1], $item[3]]}
					| instruction
					{['LIST_INSTRUCTIONS', $item[1], ['NULL']]}

	SEPARATOR : ";"
			
	startrule : #<skip: qr/[^\S\n]/> #Ignore non-newline whitespace
				instructions

_EOGRAMMARNUM_



#$Parse::RecDescent::skip = '[ \t]*';
#$Parse::RecDescent::skip = '[^\S\n]*';
my $parser = new Parse::RecDescent($grammarNum);




# Le texte doit etre passe en reference
# afin de pouvoir le modifier pour y trouver
# des erreurs de syntaxe
sub getAST{
	my $input = shift;
	return $parser->startrule($input);
}

1;
