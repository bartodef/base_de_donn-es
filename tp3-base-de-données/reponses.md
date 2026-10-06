# TP Bases de données, contraintes et triggers

## Exercice 1

Les requêtes qui peuvent violer la clé primaire de R sont :

- un insert avec A à null ou avec un A qui existe déjà
- un update qui met A à null ou à une valeur qui existe déjà

Un delete ne peut pas la violer.

Pour émuler la clé primaire, R est créée en MyISAM sans clé primaire. Deux triggers, un before insert et un before update, refusent la ligne si A est null ou si A existe déjà dans R. Pour l'update, on vérifie le doublon seulement si A change, sinon la ligne se trouverait elle-même.


```sql
insert into R values (1, 30);       -- erreur, doublon
insert into R values (null, 30);    -- erreur, null
update R set A = 2 where A = 1;     -- erreur, doublon
update R set A = 3 where A = 1;     -- ok
```

## Exercice 2

Les requêtes qui peuvent violer la clé étrangère de R vers S sont :

- un insert dans R avec un B qui n'existe pas dans S
- un update de B dans R avec une valeur qui n'existe pas dans S
- un delete dans S d'une ligne utilisée par R
- un update de B dans S sur une ligne utilisée par R

Les deux premières sont toujours rejetées. Les deux dernières dépendent de la politique choisie : set null, cascade ou reject.

Pour émuler la clé étrangère :

- sur R, deux triggers before insert et before update refusent la ligne si B n'existe pas dans S, pour les trois politiques
- sur S, deux triggers (delete et update) qui changent selon la politique

Set null : les lignes de R qui utilisaient l'ancien B passent à null.

Cascade : pour un delete, les lignes de R sont supprimées. Pour un update, elles prennent le nouveau B.

Reject : on refuse le delete ou l'update si une ligne de R utilise encore ce B.

Set null et cascade sont en after, reject est en before pour refuser avant de modifier S. Dans le script, les trois versions sont créées l'une après l'autre, c'est reject qui reste à la fin.

Tests, avec 1 et 2 dans S et les lignes (10, 1), (20, 2), (30, null) dans R :

```sql
insert into R values (40, 9);       -- erreur dans les 3 cas
delete from S where B = 1;          -- set null : R(10) passe à null, cascade : R(10) supprimé, reject : erreur
update S set B = 5 where B = 2;     -- set null : R(20) passe à null, cascade : R(20) passe à 5, reject : erreur
```

## Exercice 3

```sql
alter table EMP add constraint EMP_CK_SAL check (SAL > 0);
alter table EMP add constraint EMP_CK_HIRED check (HIRED <= curdate());
alter table EMP add constraint EMP_CK_ENAME check (ENAME = upper(ENAME) and ENAME <> '');
```

Le SGBD vérifie ces contraintes à chaque insert et update sur EMP, et aussi au moment du alter table sur les données déjà présentes.

En lançant le script:

- a marche, un salaire négatif est refusé
- b est refusée par MySQL, car curdate change tous les jours et une contrainte check doit toujours donner le même résultat
- c laisse passer 'king', car MySQL compare les chaînes sans faire attention aux majuscules. Il faut comparer en binaire, c'est ce qui est fait dans le script

Conclusion : un check ne marche pas toujours, il faut le tester. Pour b, on utilise un trigger qui refuse une date d'embauche plus grande que la date du jour.

## Exercice 4

Première contrainte : elle porte sur une seule ligne, donc un check suffit. On considère qu'un top-level manager est un employé qui n'a pas de chef (MGR à null).

```sql
alter table EMP add constraint EMP_CK_SAL_MAX check (SAL < 7500 or MGR is null);
```

Deuxième contrainte : elle porte sur plusieurs lignes, la moyenne d'un département. Un check ne peut pas faire ça et MySQL n'a pas d'assertion. On utilise donc trois triggers after sur EMP qui recalculent la moyenne du département :

- après un insert, pour le département du nouvel employé
- après un update, pour le nouveau et l'ancien département
- après un delete, car enlever un petit salaire peut faire monter la moyenne

Si la moyenne dépasse 5000, le trigger renvoie une erreur et la requête est annulée.


```sql
update EMP set SAL = 8000 where EID = 7566;     -- erreur, JONES a un chef
update EMP set SAL = 9000 where EID = 7839;     -- ok, KING n'a pas de chef
insert into EMP values (9002, 'BOB', 'CLERK', 7839, date '2020-01-01', 6000, null, 40);    -- erreur, moyenne 6000
insert into EMP values (9002, 'BOB', 'CLERK', 7839, date '2020-01-01', 4000, null, 40);    -- ok
insert into EMP values (9003, 'ANN', 'CLERK', 7839, date '2020-01-01', 5500, null, 40);    -- ok, moyenne 4750
delete from EMP where EID = 9002;                                                          -- erreur, moyenne 5500
```

## Exercice 5

Deux triggers, before insert et before update, qui refusent la ligne si le salaire est inférieur ou égal à 0.

## Exercice 6

Deux triggers, before insert et before update, qui mettent le nom en majuscules avec upper. Le nom 'doe' est enregistré 'DOE'.

## Exercice 7

On crée la table SALHIST (EID, UDATE, SAL), sans clé étrangère vers EMP car l'historique doit rester après le départ de l'employé.

Trois triggers after sur EMP :

- après un insert, on ajoute le salaire avec la date d'embauche
- après un update, si le salaire a changé, on ajoute le nouveau salaire avec la date du jour
- après un delete, on ajoute un salaire null avec la date du jour

Les employés du TP2 sont insérés au début du script, avant les triggers. On remplit donc leur historique avec un insert à la fin du script.


```sql
insert into EMP values (9001, 'doe', 'CLERK', 7782, date '2020-01-01', 1000, null, 10);
update EMP set SAL = 1500 where EID = 9001;
delete from EMP where EID = 9001;
select * from SALHIST where EID = 9001;
```

Résultat :

```
9001  2020-01-01  1000.00
9001  2026-10-06  1500.00
9001  2026-10-06  NULL
```
