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
  


## Les instruction ##  

Les instructions sont s�par�es par des points virgules, ou simplement des retours chariot.  
```  
a<-3; b<- vrai ; c<-2  
k <- si b alors a sinon c fin; w<-12  
w+k  
> 15  
```  
Elles peuvent aussi �tre regroup�es entre accolades.  
```  
incB <- { b <- b+1; affiche b; b}  
```  

## Les variables ##  
Elles sont compos�es des caract�res `[A-Za-z_][A-Za-z_']`.  
Le caract�re quote est valide pour les noms de variables mais ne peut en �tre le premier caract�re, cela permet entre autre de l'utiliser pour nommer une fonction d�riv�e.  
 
### L'affectation: ###  


On utilise 2 syntaxes, "prend la valeur" et son racourci "<-".  
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
> 3  
```  

### L'assignation: ###


Permet d'assigner des instructions � une variable  
```
b <- 3; a = affiche b  
a  
> 3  
b <- 4  
a  
> 4  
```    
```  
y = 3*x+2  
x <-2  
y  
> 8  
x <-0; y  
> 2  
```  
```  
b <- 4
a = { affiche b; b <- b-1; si b > 0 alors a fin}  
a  
> 4  
> 3  
> 2  
> 1  
```  
L'instruction suivante est valide  
```  
a = a+1  
```  
Cependant, essayer d'evaluer la valeur de "a" produira une boucle infini.  
  

L'int�ret de l'assignation peut paraitre obscure. En effet elle semble ne rien apporter, � part des complications.  
Cependant, son utilit� principale r�side dans la manipulation de "formules mathematique". Et il est pr�f�rable de s'en tenir � cette utilisation. A moins bien entendu que vous ne soyez nostalgiques des bon vieux code spaghetti, et des "formules magiques" !  

### Les contexts ###  
  
Par d�faut, les variables sont globales. Pour modifier ce comportement, nous utilisons des contexts d'�valuation.  
Par exemple, pour �tudier l'�quation d'une droite, nous pouvons faire:  
```  
y = a*x+b  
a<-1; b<-2  
x<-1  
y  
> 3 
pour x = 0 jusqu'a 3: affiche y suivant  
> 2  
> 3  
> 4  
> 5  
```  
Mais si nous voulons tester ce que donne des valeurs diff�rentes de a et b, nous pouvons �crire.  
```  
pour a<-0, b<-3: affiche y fin  
> 3  
a
> 1  
b  
> 2  
```  
```  
pour a<- -5, b <- 10: pour x=0 jusqu'a 3: affiche y suivant fin  
> 10  
> 5  
> 0  
> -5  
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
	`> 6`  

	`3 * "a"`   
	`> aaa`  
	`"a" * 3`  
	`> aaa`  

	`[1,2,3] * 3`  
	`> [3,6,9]`  

	`3 * ["a","b","c"]`  
	`> ["aaa","bbb","ccc"]`  
  
	`[1,2,3] * [4,5,6]`  
	`> [4,10,18]`  

- Division  
	`4/2`  
	`> 2`  

	`5/2`  
	`> 2.5`  

	`[4,5,7]/2`  
	`> [2,2.5,3.5]`  

	`2/[4,5,8]`  
	`> [0.5,0.4,0.25]`  
  
	`[20,30,40] / [2,3,4]`  
	`> [10,10,10]`  

	On ne peut pas diviser du texte  

- Concatenation
	`[1,2,3] & [4,5]`  
	`> [1,2,3,4,5]`  
  
	`"Salut " & "le " & "Monde"`  
	`> Salut le Monde`  
  
	`1 & 2`  
	`> 12`  

- Parenthesage
	`a <- [1,2,3,4]`  
	`a(0)`  
	`> 1`  
  
	`[1,2,3,4](0)`  
	`> 1`  
  
	`b <- "Coucou le monde"`  
	`b(0)`  
	`> C`  
  
	`"Salut le monde !"(0)`  
	`> S`  
  
	`c <- 3`  
	`c(2)`  
	`> 6`  
	`3(2)`  
	`> 6`  
	`x <- 1`  
	`(x-2)(x+2)`  
	`> -3`  
  
	`f(x) = 3*x + 2`  
	`f(1)`  
	`> 5`  


Les structures du language:  
---------------------------

- Les conditions  
	`si test alors v sinon w fin`  
```	
	si a=b alors  
		k<-f(z)  
		g(k)  
	sinon  
		a<-a+1  
		a  
	fin  
```   

	Les conditions renvoient des valeur, il est par exemple possible d'�crire:  

```
	v <- 2 + si vrai alors 1 sinon 2 fin   
```  

	On peut ainsi �crire la fonction factorielle comme suit:  

```  
	fact(n) = si n=1 alors 1 sinon n*fact(n-1) fin  
```  


- Les boucles  
	La boucle tant que
```  
	a<- vrai
	tant que a:
		b<-b-1  
		affiche b  
		si b=0 alors a <- faux fin  
	fin  
```  

	La boucle pour (inspir�e du BASIC, comme tout ce qui peut sembler incoh�rent).  

```
	pour index = 3 jusqu'a 10:  
		affiche index  
	suivant  
```  

	On peut aussi utiliser un incr�ment  

```
	pour j = 12 jusqu'a 15 increment 0.2:  
		affiche j  
	suivant  
```  

	La boucle pour chaque.  
	Elle permet d'it�rer � travers des tableaux ou du texte ( ou certaines structure particuli�res que nous verrons plus tard).  

```  
	pour chaque element de [1,3,4,6]:  
		affiche element  
	fin  
```  

```  
	pour chaque lettre de "abcde":  
		affiche lettre  
	fin  
```  

De m�me que pour les conditions, les boucles renvoient une valeur, celle de la derni�re instruction ex�cut�e.  
Ce comportement est le m�me pour la d�finition de contextes ("pour"):  
```  
	y = 3*x+2  
	v <- pour x<-4: y fin  
	v  
	> 14  
``` 

