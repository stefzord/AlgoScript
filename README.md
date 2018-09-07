# AlgoScript
=============

Language destin� � l'apprentissage de la programmation.  
La syntaxe est d�finie en fran�ais (mais les accents ne sont pas encore int�gr�s).  
Le prototype est cod� en perl.  
  
Il supporte actuellement les type suivant:
- num�rique (pas de diff�rence entre les entiers et les flottants; la virgule est d�finie par un point)  
- texte d�finis par des guillemets (pas de caract�re d'�chapement)  
- tableaux d�finis par les crochets  
- bool�ens (vrai / faux)  
- rien (peut �tre assimil� � un tableau vide ou un texte vide)
- les fonctions  
  
Les variables:  
Elles sont compos�es des caract�res `[A-Za-z_'][A-Za-z_']`.  
Le caract�re quote est valide pour les noms de variables mais ne peut en �tre le premier caract�re, cela permet entre autre de l'utiliser pour nommer une fonction d�riv�e.  


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

  
Pour les fonctions, le cas est l�g�rement plus sophistiqu�. Une fonction est d�finie par ses arguments et le corps de la fonction. Une d�finition de fonction prenant les arguments x et y et renvoyant leur somme est de la forme:  
`\(x,y){x+y}`  
Si l'on veut affecter cette fonction � la variable f, il nous suffit d'�crire:  
`f <- \(x,y){x+y}`  
Que l'on peut �crire de fa�on plus naturelle en:  
`f(x,y) = x+y`  
Les fonctions �tant des fermetures, nous pouvons par exemple d�finir la d�riv�e d'une fonction ainsi:  
```
epsilon <- 0.001
d(f)=\(x){(f(x+epsilon)-f(x))/epsilon}  
g(x) = 3*x+2  
f'<- d(g)  
f'(4)
```  


Les op�rations:
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

