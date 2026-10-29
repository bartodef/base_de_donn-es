# Guide du TP noté, pas à pas

Ce guide explique tout le TP depuis le début : les notions, chaque ligne de code, ce qu'il faut faire dans IntelliJ et ce qu'il faut mettre dans le rapport.

Il est à part du dossier du TP, ne le rends pas avec ton travail.


# 0. Les notions de base

## Base, table, ligne, colonne

Une base de données (ici Suppliers) contient des tables. Une table ressemble à un tableau Excel :

- chaque colonne a un nom et un type (nombre, texte, date)
- chaque ligne est un élément (un client, un produit, une commande)

## Les 3 tables du TP

products : les produits

- pid : le numéro du produit
- pname : son nom
- price : son prix
- origin : son pays d'origine

customers : les clients

- cid : le numéro du client
- cname : son nom
- residence : son pays

orders : les commandes

- pid : le produit commandé
- cid : le client qui commande
- odate : la date
- quantity : la quantité

orders fait le lien entre les deux autres tables : une ligne de orders dit "tel client a commandé tel produit tel jour".

## Clé primaire

La clé primaire (primary key) est la colonne qui identifie chaque ligne de façon unique. Deux clients ne peuvent pas avoir le même cid, et cid ne peut pas être vide.

Dans orders, la clé primaire est (pid, cid, odate) : un client peut commander le même produit plusieurs fois, mais pas deux fois le même jour.

## Clé étrangère

Une clé étrangère (foreign key) oblige une colonne à contenir une valeur qui existe dans une autre table. Le cid de orders doit exister dans customers : on ne peut pas faire une commande pour un client qui n'existe pas.

## NULL

NULL veut dire "valeur inconnue". Ce n'est pas zéro, ce n'est pas un texte vide.

Le piège : toute comparaison avec NULL ne donne ni vrai ni faux, mais "inconnu". Par exemple NULL = 'France' n'est pas vrai, et NULL <> 'France' n'est pas vrai non plus. Une ligne n'est gardée par un where que si la condition est vraie. Donc une ligne avec NULL disparaît souvent sans qu'on le veuille.

Dans le TP, le client Blake a residence à NULL. Il faut y penser à chaque requête.

## La forme d'une requête

```sql
select colonnes      -- ce qu'on veut afficher
from tables          -- où on cherche
where conditions;    -- quelles lignes on garde
```

Le point-virgule marque la fin de la requête.

## Les alias

```sql
from customers c
```

Le c est un surnom pour la table customers. Ensuite on écrit c.cname au lieu de customers.cname. C'est plus court, et c'est obligatoire quand la même table est utilisée deux fois dans une requête.

## Lancer une requête dans IntelliJ

1. Sélectionner toute la requête à la souris, du select jusqu'au point-virgule.
2. Appuyer sur Ctrl + Entrée.
3. Le résultat s'affiche en bas.

Si on ne sélectionne pas tout, IntelliJ peut lancer seulement un morceau et afficher une erreur.

## Faire une capture

Windows + Maj + S, puis on entoure la zone avec la souris. La capture est copiée, on la colle dans le rapport avec Ctrl + V.


# 1. Préparer

1. Lancer database.sql : clic droit sur le fichier, Run, choisir @localhost. Ça crée la base Suppliers avec ses données.
2. Dans le panneau Database, cliquer sur le "x of 9" à côté de @localhost et cocher Suppliers.
3. Ouvrir partie1.sql, sélectionner la ligne `use Suppliers;` et faire Ctrl + Entrée. Cette ligne dit à MariaDB sur quelle base travailler.

Ne modifie jamais database.sql, l'énoncé l'interdit.


# 2. Partie 1 : les requêtes

## Requête 1

Question : les clients qui n'ont commandé que des produits venant de pays étrangers.

Reformulation : on garde un client si toutes ses commandes sont des produits d'un autre pays que le sien.

Méthode : avec le mot "que", on raisonne à l'envers. On garde le client s'il n'existe aucune commande qui ne va pas. C'est plus facile à écrire en SQL.

```sql
select c.cid, c.cname
from customers c
where exists (select * from orders o where o.cid = c.cid)
  and not exists (select *
                  from orders o, products p
                  where o.pid = p.pid
                    and o.cid = c.cid
                    and (p.origin = c.residence or p.origin is null or c.residence is null));
```

Ligne par ligne :

- `select c.cid, c.cname` : on affiche le numéro et le nom du client.
- `from customers c` : on parcourt les clients un par un, le client en cours s'appelle c.
- `where exists (select * from orders o where o.cid = c.cid)` : exists est vrai si la petite requête entre parenthèses trouve au moins une ligne. Ici : le client a au moins une commande. Sans cette ligne, un client qui n'a rien commandé serait gardé, car il n'a "aucune mauvaise commande".
- `and not exists (select *` : not exists est vrai si la petite requête ne trouve rien. On va chercher une mauvaise commande, et on garde le client si on n'en trouve pas.
- `from orders o, products p` : on prend les commandes et les produits.
- `where o.pid = p.pid` : on relie chaque commande à son produit. C'est une jointure : sans elle, on aurait toutes les combinaisons commande et produit.
- `and o.cid = c.cid` : seulement les commandes du client c, celui de la requête principale.
- `and (p.origin = c.residence or p.origin is null or c.residence is null)` : c'est la définition d'une mauvaise commande. Soit le produit vient du même pays que le client, soit un des deux pays est inconnu. Si un pays est NULL, on ne peut pas dire que le produit est étranger, donc on considère que ça ne va pas.

Résultat : Jones et Smith.

Vérification à la main : Dupond (France) a commandé du lait de France, il est exclu. Gupta (India) a commandé du thé d'Inde, exclu. Blake n'a pas de pays, exclu.

Dans le rapport :

- le titre "Requête 1" et la question
- la requête en texte (copier-coller)
- la capture du résultat
- une phrase : "On garde les clients qui ont au moins une commande et aucune commande d'un produit de leur pays. Si le pays du client ou du produit est inconnu, on ne peut pas dire que le produit est étranger, donc le client n'est pas gardé."

## Requête 2

Question : les clients qui ont commandé tous les produits à moins de 5 dollars.

Méthode : "tous" veut dire division. On l'écrit avec deux not exists : on garde le client s'il n'existe aucun produit à moins de 5 dollars qu'il n'a pas commandé. C'est une double négation : "pas de produit pas commandé" veut dire "tous commandés".

```sql
select c.cid, c.cname
from customers c
where not exists (select *
                  from products p
                  where p.price < 5
                    and not exists (select *
                                    from orders o
                                    where o.cid = c.cid
                                      and o.pid = p.pid));
```

Ligne par ligne :

- `select c.cid, c.cname from customers c` : pour chaque client c.
- `where not exists (select * from products p where p.price < 5` : on cherche un produit p à moins de 5 dollars...
- `and not exists (select * from orders o where o.cid = c.cid and o.pid = p.pid)` : ... que le client c n'a jamais commandé, c'est-à-dire qu'il n'y a pas de commande avec ce client et ce produit.
- si on ne trouve aucun produit comme ça, le client a tout commandé, on le garde.

Le chocolat à 5.0 n'est pas pris : moins de 5 veut dire strictement inférieur (<), pas inférieur ou égal (<=).

Résultat : Jones, Blake, Dupond, Smith. Les produits à moins de 5 dollars sont le sucre et le lait, Gupta n'a jamais commandé de lait.

Dans le rapport : la requête, la capture, et "C'est une division : on garde le client s'il n'existe aucun produit à moins de 5 dollars qu'il n'a pas commandé."

## Requête 3

Question : les clients qui habitent dans les mêmes pays que les clients nommés Smith, sans les Smith.

Méthode : on cherche d'abord les pays des Smith avec une sous-requête, puis on garde les clients dont le pays est dans cette liste.

```sql
select c.cid, c.cname, c.residence
from customers c
where c.cname <> 'Smith'
  and c.residence in (select s.residence
                      from customers s
                      where s.cname = 'Smith');
```

Ligne par ligne :

- `select c.cid, c.cname, c.residence from customers c` : pour chaque client c, on affiche son numéro, son nom et son pays.
- `where c.cname <> 'Smith'` : <> veut dire "différent de". On enlève les Smith, comme demandé.
- `and c.residence in (...)` : in est vrai si la valeur est dans la liste donnée par la sous-requête.
- `select s.residence from customers s where s.cname = 'Smith'` : la liste des pays des Smith. On utilise la table customers une deuxième fois, avec un autre alias (s), pour ne pas la mélanger avec c.

Pourquoi in et pas = : il peut y avoir plusieurs Smith dans le jeu de données du prof, donc plusieurs pays. = ne marche qu'avec une seule valeur et donnerait une erreur.

Un client avec un pays NULL n'est jamais gardé : NULL in (...) n'est pas vrai. C'est le bon comportement, on ne sait pas où il habite.

Résultat : aucune ligne. Smith est le seul client de Great Britain. C'est la bonne réponse.

Dans le rapport : la requête, la capture du tableau vide, et "Aucun résultat, car Smith est le seul client de Great Britain. Le in permet de gérer le cas où il y a plusieurs Smith."

## Requête 4

Question : les produits dont le montant moyen par commande est le plus élevé.

Le montant d'une commande, c'est le prix multiplié par la quantité. On calcule la moyenne de ce montant pour chaque produit, puis on garde le ou les produits qui ont la plus grande moyenne.

```sql
select p.pid, p.pname, avg(p.price * o.quantity) as montant_moyen
from products p, orders o
where p.pid = o.pid
group by p.pid, p.pname
having avg(p.price * o.quantity) >= all (select avg(p2.price * o2.quantity)
                                         from products p2, orders o2
                                         where p2.pid = o2.pid
                                         group by p2.pid);
```

Ligne par ligne :

- `select p.pid, p.pname, avg(p.price * o.quantity) as montant_moyen` : on affiche le produit et la moyenne de prix fois quantité. avg calcule une moyenne. as montant_moyen donne un nom à la colonne du résultat.
- `from products p, orders o where p.pid = o.pid` : on relie chaque commande à son produit.
- `group by p.pid, p.pname` : on fait des paquets, un par produit. avg calcule la moyenne dans chaque paquet. Règle du cours : toute colonne du select qui n'est pas dans un avg, sum, count... doit être dans le group by.
- `having ...` : c'est comme where, mais sur les paquets, après le group by. On ne peut pas mettre avg dans un where.
- `>= all (...)` : vrai si la moyenne est plus grande ou égale à toutes les valeurs de la liste.
- la sous-requête calcule la moyenne de chaque produit. Donc on garde le produit dont la moyenne est au moins aussi grande que toutes les autres : c'est le maximum.

Pourquoi pas order by ... limit 1 : s'il y a deux produits ex aequo, limit 1 n'en montre qu'un. Avec >= all, on les a tous. Le prof teste avec d'autres données, il faut que ça marche aussi dans ce cas.

Un produit jamais commandé n'a pas de moyenne, il n'apparaît pas. C'est normal.

Résultat : tea, 24. Le thé a 5 commandes : 30, 20, 30, 20, 20, ce qui fait 120 divisé par 5.

Dans le rapport : la requête, la capture, et "Le montant d'une commande est le prix fois la quantité. On garde le ou les produits dont la moyenne est supérieure ou égale à celle de tous les produits, ce qui gère les ex aequo."

## Requête 5

Question : les paires de clients qui ont commandé le même produit en 2014, avec ce produit. Colonnes cname1, cname2, pname, avec cname1 < cname2.

Méthode : on prend deux commandes en même temps (o1 et o2), du même produit, toutes les deux en 2014, et on affiche les deux clients. C'est une auto-jointure : la table orders est utilisée deux fois.

```sql
select distinct c1.cname as cname1, c2.cname as cname2, p.pname
from orders o1, orders o2, customers c1, customers c2, products p
where o1.pid = o2.pid
  and o1.cid = c1.cid
  and o2.cid = c2.cid
  and o1.pid = p.pid
  and year(o1.odate) = 2014
  and year(o2.odate) = 2014
  and c1.cname < c2.cname;
```

Ligne par ligne :

- `select distinct ...` : distinct enlève les lignes en double.
- `from orders o1, orders o2, customers c1, customers c2, products p` : deux commandes, les deux clients qui vont avec, et le produit.
- `where o1.pid = o2.pid` : les deux commandes portent sur le même produit.
- `and o1.cid = c1.cid and o2.cid = c2.cid` : on récupère le client de chaque commande.
- `and o1.pid = p.pid` : on récupère le produit, pour afficher son nom.
- `and year(o1.odate) = 2014 and year(o2.odate) = 2014` : year donne l'année d'une date. Les deux commandes doivent être de 2014.
- `and c1.cname < c2.cname` : demandé par l'énoncé. Ça évite d'avoir un client avec lui-même (Jones, Jones) et la même paire dans les deux sens (Jones, Smith et Smith, Jones). < sur du texte compare dans l'ordre alphabétique.

Pourquoi distinct : Jones a commandé du sucre deux fois en 2014. Sans distinct, la paire Dupond, Jones, sugar apparaîtrait deux fois.

Résultat : 16 lignes.

Dans le rapport : la requête, la capture, et "On joint deux fois orders sur le même produit en 2014. La condition cname1 < cname2 évite les paires en double et un client avec lui-même, et distinct enlève les doublons quand un client a commandé plusieurs fois le même produit."


# 3. Partie 2 : contraintes et trigger

## Préparer

1. Lancer suppliers2.sql : clic droit, Run, @localhost. Ça crée la base Suppliers2.
2. Dans le panneau Database, cocher Suppliers2.
3. Ouvrir partie2.sql et lancer `use Suppliers2;`.

## Question 1 : ce qui a changé dans suppliers2.sql

suppliers2.sql est une copie de database.sql avec 3 changements.

Changement 1 : le nom de la base.

```sql
drop DATABASE if EXISTS Suppliers2;
CREATE DATABASE Suppliers2;
use Suppliers2;
```

- drop database if exists : supprime la base si elle existe déjà, pour pouvoir relancer le script.
- create database : crée la base.
- use : on travaille dedans.

Changement 2 : `engine=InnoDB` à la fin de chaque create table. Le moteur, c'est la partie de MariaDB qui stocke la table. InnoDB est celui qui vérifie vraiment les clés étrangères. C'est le moteur par défaut, mais on l'écrit pour être sûr.

Changement 3 : les clés étrangères de orders.

```sql
constraint orders_fk_pid foreign key (pid) references products (pid)
    on delete restrict on update restrict,
constraint orders_fk_cid foreign key (cid) references customers (cid)
    on delete restrict on update restrict
```

- `constraint orders_fk_cid` : le nom de la contrainte, il apparaît dans les messages d'erreur.
- `foreign key (cid) references customers (cid)` : le cid de orders doit exister dans customers. Ça répond au troisième point de l'énoncé : une commande avec un client ou un produit qui n'existe pas est refusée.
- `on delete restrict` : si on supprime un client qui a des commandes, la suppression est refusée.
- `on update restrict` : si on change le cid d'un client qui a des commandes, la modification est refusée.

Les autres choix possibles, à connaître pour demain :

- cascade : supprime ou modifie aussi les commandes
- set null : met le cid des commandes à NULL
- restrict : refuse, c'est ce que demande l'énoncé

L'énoncé interdit les triggers pour cette question, la clé étrangère suffit.

## Question 1 : les tests

Lancer chaque ligne une par une. Une erreur ici est le résultat attendu : elle prouve que la contrainte marche.

```sql
delete from customers where cid = 1;
```
Supprime le client 1. Il a des commandes, donc erreur 1451 "Cannot delete or update a parent row".

```sql
delete from customers where cid in (1, 2);
```
Supprime plusieurs clients d'un coup. L'énoncé parle d'une ou plusieurs lignes. Erreur 1451, et aucun des deux n'est supprimé.

```sql
update customers set cid = 100 where cid = 1;
```
Change le numéro du client 1. Ses commandes pointeraient vers un client qui n'existe plus, donc erreur 1451.

```sql
insert into orders values (99, 1, date '2024-01-01', 1);
```
Commande du produit 99, qui n'existe pas. Erreur 1452 "Cannot add or update a child row".

```sql
insert into orders values (1, 99, date '2024-01-01', 1);
```
Commande du client 99, qui n'existe pas. Erreur 1452.

```sql
insert into customers values (6, 'Test', 'Spain');
delete from customers where cid = 6;
```
On ajoute un client sans commande puis on le supprime. Ça marche : restrict ne bloque que s'il y a des commandes.

```sql
insert into orders values (1, 5, date '2024-01-01', 1);
delete from orders where pid = 1 and cid = 5 and odate = date '2024-01-01';
```
Une commande correcte est acceptée, puis on la supprime pour remettre la base comme avant.

Dans le rapport :

- le code modifié de suppliers2.sql, en texte (le create table orders suffit, avec les lignes restrict)
- une phrase : "On utilise des clés étrangères avec on delete restrict et on update restrict, en InnoDB. Le SGBD refuse alors la suppression ou la modification d'un client qui a des commandes, et l'ajout d'une commande avec un produit ou un client qui n'existe pas."
- chaque test en texte, avec la capture du message d'erreur ou du succès

## Question 2 : la table de log

Un log est un historique : on y note chaque changement de pays d'un client.

```sql
create table customer_residence_log (
    log_id          int auto_increment,
    customer_id     int not null,
    old_residence   varchar(50),
    new_residence   varchar(50),
    constraint customer_residence_log_pk primary key (log_id)
) engine=InnoDB;
```

Ligne par ligne :

- `create table customer_residence_log (` : crée la table avec le nom demandé.
- `log_id int auto_increment` : un nombre que MariaDB remplit tout seul : 1, puis 2, puis 3...
- `customer_id int not null` : le numéro du client modifié, obligatoire.
- `old_residence varchar(50)` : l'ancien pays. varchar(50) est un texte de 50 caractères maximum, la même taille que residence dans customers. Pas de not null : l'ancien pays peut être inconnu.
- `new_residence varchar(50)` : le nouveau pays.
- `constraint ... primary key (log_id)` : log_id est la clé primaire, comme demandé.

Pas de clé étrangère vers customers : sinon on ne pourrait plus supprimer un client qui a un historique.

## Question 2 : le trigger

Un trigger (déclencheur) est un bout de code que MariaDB lance tout seul quand quelque chose arrive sur une table. Ici : à chaque modification d'un client.

```sql
delimiter $$

create trigger customers_residence_update
before update on customers
for each row
begin
    if not (NEW.residence <=> OLD.residence) then
        insert into customer_residence_log (customer_id, old_residence, new_residence)
        values (OLD.cid, OLD.residence, NEW.residence);
    end if;
end $$

delimiter ;
```

Ligne par ligne :

- `delimiter $$` : le trigger contient des points-virgules à l'intérieur. Sans ça, MariaDB croirait que la commande s'arrête au premier point-virgule. On dit donc que la fin de commande est $$ le temps d'écrire le trigger.
- `create trigger customers_residence_update` : crée le trigger et lui donne un nom.
- `before update on customers` : il se lance avant chaque update sur customers, comme le demande l'énoncé.
- `for each row` : il se lance une fois pour chaque ligne modifiée. Si un update modifie 3 clients, il se lance 3 fois.
- `begin` : début du code du trigger.
- `if not (NEW.residence <=> OLD.residence) then` : OLD est la ligne avant la modification, NEW la ligne après. On vérifie que le pays a changé. MariaDB ne sait pas faire un trigger seulement sur une colonne, donc le trigger se lance aussi quand on change le nom : ce if permet de n'écrire dans le log que si le pays change.
- Pourquoi <=> et pas = : <=> est l'égalité qui marche avec NULL. NULL <=> NULL est vrai, NULL <=> 'Italy' est faux. Avec =, le passage de NULL à Italy ne serait pas détecté, à cause du piège du NULL.
- `insert into customer_residence_log (customer_id, old_residence, new_residence)` : on ajoute une ligne dans le log. On ne donne pas log_id, il se remplit tout seul.
- `values (OLD.cid, OLD.residence, NEW.residence);` : le numéro du client, l'ancien pays, le nouveau pays.
- `end if;` : fin du if.
- `end $$` : fin du trigger, avec le délimiteur $$.
- `delimiter ;` : on remet le point-virgule comme fin de commande.

Dans IntelliJ : sélectionner tout le bloc, de delimiter $$ jusqu'à delimiter ;, puis Ctrl + Entrée. Si IntelliJ refuse, sélectionner seulement de create trigger jusqu'à end (sans le $$).

## Question 2 : le test

```sql
update customers set residence = 'Germany' where cid = 1;   -- USA devient Germany
update customers set residence = 'Italy' where cid = 2;     -- NULL devient Italy
update customers set residence = null where cid = 3;        -- France devient NULL
update customers set cname = 'JONES' where cid = 1;         -- on change le nom, pas le pays
select * from customers;
select * from customer_residence_log;
```

Résultat : 3 lignes dans le log. Le changement de nom n'est pas noté, c'est voulu.

Dans le rapport :

- le create table et le create trigger en texte
- une phrase : "Le trigger se lance avant chaque update de customers et n'écrit dans le log que si la résidence change. On compare avec <=> pour que les changements depuis ou vers NULL soient aussi enregistrés."
- les update de test et la capture des deux select


# 4. Partie 3 : transactions

## Les notions

Une transaction est un groupe de requêtes qui forme un tout.

- `start transaction;` : on commence.
- `commit;` : on valide, les changements deviennent définitifs et visibles par les autres.
- `rollback;` : on annule tout ce qui a été fait depuis le start transaction.

Sans start transaction, chaque requête est validée tout de suite : c'est l'autocommit.

Quand deux personnes travaillent en même temps sur la base, il peut y avoir des problèmes. Celui du TP est la lecture fantôme : une transaction relance la même requête et voit une ligne de plus, ajoutée entre temps par quelqu'un d'autre.

Le niveau d'isolation dit à quel point une transaction est protégée des autres. Du moins protégé au plus protégé :

- read uncommitted : on voit même ce que les autres n'ont pas encore validé
- read committed : on voit ce que les autres ont validé, même en cours de transaction, donc les fantômes sont possibles
- repeatable read : on lit une photo de la base prise à la première lecture, c'est le niveau par défaut de MariaDB
- serializable : on verrouille ce qu'on lit, les autres doivent attendre, plus aucun fantôme

`set session transaction isolation level ...;` choisit le niveau pour la session.

## Préparer les deux sessions

1. Dans le panneau Database, clic droit sur @localhost, New, Query Console. Recommencer une deuxième fois.
2. La première console est la session A, la deuxième la session B. Tu peux mettre les deux côte à côte en faisant glisser un onglet.
3. Dans chaque console, taper `use Suppliers;` et faire Ctrl + Entrée.
4. Dans A, taper `select version();` pour connaître ta version de MariaDB.

On copie les lignes de partie3.sql dans la bonne console, dans l'ordre des étapes. Les captures doivent montrer le code, les commentaires et les résultats : garde les commentaires quand tu copies.

## Tâche 1.a : montrer la lecture fantôme

Session A, étape 1 :
```sql
set session transaction isolation level read committed;
start transaction;
select * from customers where residence = 'France';
```
On se met en read committed, le niveau où les fantômes sont possibles. On commence une transaction et on lit les clients en France : 1 ligne, Dupond.

Session B, étape 2 :
```sql
insert into customers values (6, 'Martin', 'France');
```
B ajoute un client en France. B est en autocommit, l'ajout est validé tout de suite.

Session A, étape 3 :
```sql
select * from customers where residence = 'France';
commit;
```
A relance exactement la même requête, dans la même transaction : 2 lignes, Martin est apparu. C'est la lecture fantôme. Puis A termine sa transaction.

Session B, étape 4 :
```sql
delete from customers where cid = 6;
```
On enlève Martin pour remettre la base comme avant.

Capture : les deux consoles, avec le premier select de A (1 ligne) et le deuxième (2 lignes).

## Tâche 1.b : empêcher la lecture fantôme

Même scénario, mais en serializable.

Session A, étape 1 :
```sql
set session transaction isolation level serializable;
start transaction;
select * from customers where residence = 'France';
```
1 ligne. En serializable, A pose un verrou sur ce qu'elle lit.

Session B, étape 2 :
```sql
insert into customers values (6, 'Martin', 'France');
```
L'insert ne se termine pas, il tourne : B attend que A libère son verrou. C'est normal, c'est ce qu'on veut montrer. Va vite à l'étape 3, au bout de 50 secondes B abandonne avec une erreur.

Session A, étape 3 :
```sql
select * from customers where residence = 'France';
commit;
```
Toujours 1 ligne : pas de fantôme. Le commit libère le verrou, et l'insert de B se termine tout de suite.

Session B, étape 4 :
```sql
delete from customers where cid = 6;
```

Capture : B en train d'attendre, puis A avec ses deux select identiques.

## Tâche 2.a : repeatable read

Session A, étape 1 :
```sql
set session transaction isolation level repeatable read;
start transaction;
select * from orders where pid = 1;
```
2 commandes du produit 1.

Session B, étape 2 :
```sql
insert into orders values (1, 5, date '2015-01-01', 1);
```
B ajoute une commande du produit 1. Elle passe tout de suite : en repeatable read, A ne verrouille pas ce qu'elle lit.

Session A, étape 3 :
```sql
select * from orders where pid = 1;
```
Toujours 2 lignes : A lit la photo prise à sa première lecture, elle ne voit pas la commande de B.

Session A, étape 4 :
```sql
update orders set quantity = quantity + 1 where pid = 1;
select * from orders where pid = 1;
rollback;
```
A ajoute 1 à la quantité des commandes du produit 1. Le résultat dépend de ta version :

- MariaDB avant 11.6 : 3 lignes modifiées. L'update travaille sur la vraie base, pas sur la photo, donc il touche aussi la commande de B. Le select suivant montre 3 lignes : le fantôme apparaît.
- MariaDB 11.6 et plus : erreur 1020 "Record has changed since last read". MariaDB refuse de modifier une ligne qui n'était pas dans la photo et annule la transaction de A.

Le rollback annule la modification.

Session B, étape 5 :
```sql
delete from orders where pid = 1 and cid = 5 and odate = date '2015-01-01';
```

## Tâche 2.b : serializable

Session A, étape 1 :
```sql
set session transaction isolation level serializable;
start transaction;
select * from orders where pid = 1;
```
2 lignes, et A verrouille ce qu'elle lit.

Session B, étape 2 :
```sql
insert into orders values (1, 5, date '2015-01-01', 1);
```
Bloqué, B attend.

Session A, étape 3 :
```sql
select * from orders where pid = 1;
update orders set quantity = quantity + 1 where pid = 1;
select * from orders where pid = 1;
rollback;
```
Toujours 2 lignes, l'update ne modifie que 2 lignes. Le rollback annule et libère le verrou : l'insert de B se termine.

Session B, étape 4 :
```sql
delete from orders where pid = 1 and cid = 5 and odate = date '2015-01-01';
```

## Si ça se passe mal

Si tu te trompes d'ordre ou si une console reste bloquée : fais `rollback;` dans les deux consoles, puis relance database.sql pour repartir d'une base propre.

## Dans le rapport pour la partie 3

Pas besoin de coller le code, l'énoncé dit que les captures suffisent. Pour chaque tâche :

- les captures des deux consoles, avec le code, les commentaires et les résultats
- l'explication

Tâche 1 : "En read committed, A relance la même requête et voit un client de plus, ajouté par B entre temps : c'est une lecture fantôme. En serializable, A verrouille ce qu'elle lit, l'insert de B attend la fin de A, et A voit toujours le même résultat."

Tâche 2 : "En repeatable read, B n'est pas bloquée et A lit toujours la même photo de la base. Mais quand A modifie les données, l'update voit la ligne de B : elle est modifiée et apparaît ensuite (ou, avec MariaDB 11.6 et plus, la transaction de A est annulée). En serializable, B est bloquée tant que A n'a pas fini, A ne voit jamais la ligne de B. Repeatable read laisse travailler les autres en même temps mais protège moins, serializable protège complètement mais fait attendre les autres."


# 5. Le plan du rapport

1. Page de garde : nom, prénom, titre du TP, date.
2. Partie 1 : pour chaque requête, la question, la requête en texte, la capture du résultat, une ou deux phrases d'explication.
3. Partie 2 question 1 : le code modifié, les tests en texte, les captures.
4. Partie 2 question 2 : le create table, le trigger, le test, les captures.
5. Partie 3 : pour chaque tâche, les captures et l'explication.


# 6. À retenir pour le prochain TP

- "que" (n'avoir fait que...) : exists pour au moins un, plus not exists pour aucun contre-exemple.
- "tous" : division avec deux not exists l'un dans l'autre.
- "les mêmes que..." : in avec une sous-requête, car il peut y avoir plusieurs valeurs.
- "le plus élevé", "le maximum" : group by, having et >= all. Jamais limit 1, à cause des ex aequo.
- "les paires" : la même table deux fois avec deux alias, plus une condition < pour éviter les doublons et la paire avec soi-même.
- un doublon possible dans le résultat : distinct.
- toujours se demander ce qui se passe avec NULL, avec les doublons, et avec un élément qui n'a rien (client sans commande, produit jamais commandé).
- ne jamais écrire un id en dur dans une requête de la partie 1, le prof teste avec d'autres données.
- refuser une suppression sans trigger : clé étrangère avec on delete restrict.
- un trigger : delimiter, before ou after, insert, update ou delete, for each row, NEW et OLD.
- comparer des valeurs qui peuvent être NULL : <=>.
- transaction : start transaction, commit, rollback, et le niveau avec set session transaction isolation level.
