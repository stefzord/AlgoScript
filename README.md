# AlgoScript
=============

Language destiné à l'apprentissage de la programmation.  
La syntaxe est définie en français (mais les accents ne sont pas encore intégrés).  
Le prototype est codé en perl.  
  
Il supporte actuellement les type suivant:
- numérique (pas de différence entre les entiers et les flottants; la virgule est définie par un point)  
- texte définis par des guillemets (pas de caractère d'échapement)  
- tableaux définis par les crochets  
- booléens (vrai / faux)  
- rien (peut être assimilé à un tableau vide ou un texte vide)
- les fonctions  
  
Les variables:  
Elles sont composées des caractères `[A-Za-z_'][A-Za-z_']`.  
Le caractère quote est valide pour les noms de variables mais ne peut en être le premier caractère, cela permet entre autre de l'utiliser pour nommer une fonction dérivée.  


## Les instruction ##


L'affectation:  
--------------

On utilise 2 syntaxes, "prend la valeur" et "<-".  
Exemples  
`a prend la valeur "Salut le monde"`  
`b prend la valeur 3.14159`  
`_mon_nom_de_variable <- "Valeur de ma variable"`  
`prend_la_valeur prend la valeur "prend la valeur"`  
`f <- faux`  
`v <- vrai`  
`tab <- [1,"Texte",b]`  
`r <- rien`  
`l <- []`  
`t <- ""`  

  
Pour les fonctions, le cas est légèrement plus sophistiqué. Une fonction est définie par ses arguments et le corps de la fonction. Une définition de fonction prenant les arguments x et y et renvoyant leur somme est de la forme:  
`\(x,y){x+y}`  
Si l'on veut affecter cette fonction à la variable f, il nous suffit d'écrire:  
`f <- \(x,y){x+y}`  
Que l'on peut écrire de façon plus naturelle en:  
`f(x,y) = x+y`  
Les fonctions étant des fermetures, nous pouvons par exemple définir la dérivée d'une fonction ainsi:  
```
epsilon <- 0.001
d(f)=\(x){(f(x+epsilon)-f(x))/epsilon}  
g(x) = 3*x+2  
f'<- d(g)  
f'(4)
```  


Les opérations:
---------------

- Addition
	`1+1`  
	`> 2`  

	`"Bonjour " + "le monde "`
	`> Bonjour le monde`  

	`1+"a"`  
	`> 1a`  

	`1 + [1,2,3]`  
	`> [2,3,4]`  

	`[1,2,3] + [4,5,6]`  
	`> [5,7,9]`  

- Soustraction
	`2-1`  
	`> 1`  

	`[1,2,3] - 1`  
	`> [0,1,2]`  
	`1 - [1,2,3]`  
	`> [0,-1,-2]`  

	`[4,5,6] - [1,2,3]`  
	`> [3,3,3]`  

	On ne peut pas soustraire du texte  

- Multiplication
	`3 * 2`  
	`> 2`  

	`3 * "a"`  
	`> aaa`  
	`"a" * 3`  
	`> aaa`  

	`[1,2,3] * 3`  
	`> [3,6,9]`  

	`3 * ["a","b","c"]`  
	`> ["aaa","bbb","ccc"]`

- Division
	`4/2`
	`> 2`

	`5/2`
	`> 2.5`

	`[4,5,7]/2`
	`> [2,2.5,3.5]`  

	`2/[4,5,8]`  
	`> [0.5,0.4,0.25]`  

	On ne peut pas diviser du texte


Les structures du language:
---------------------------

- Les conditions
	`si test alors v sinon w fin`  
```	si a=b alors  
		k<-f(z)  
		g(k)  
	sinon  
		a<-a+1  
		a  
	fin  
```

