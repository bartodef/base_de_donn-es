# TP Bases de données — Contraintes et triggers

Script : `tp3.sql`.

## Exercice 1

Requêtes qui peuvent violer la clé primaire de `R(A, B)` :

- `INSERT` avec un `A` à `NULL` ou un `A` déjà présent dans `R`.
- `UPDATE` qui met `A` à `NULL` ou à une valeur déjà présente dans `R`.

Un `DELETE` ne peut pas la violer.

Émulation : `R` est créée en MyISAM sans clé primaire, et deux triggers `before insert` / `before update` refusent la ligne avec `signal`.

```sql
create trigger R_PK_INSERT
before insert on R
for each row
begin
    if NEW.A is null or exists (select * from R where A = NEW.A) then
        signal sqlstate '23000' set message_text = 'Violation de la cle primaire de R';
    end if;
end $$
```

Pour l'`update`, on ne teste le doublon que si `A` change (`NEW.A <> OLD.A`), sinon la ligne se trouverait elle-même.

Tests :

```sql
insert into R values (1, 30);       -- erreur : doublon
insert into R values (null, 30);    -- erreur : NULL
update R set A = 2 where A = 1;     -- erreur : doublon
update R set A = 3 where A = 1;     -- ok
```

## Exercice 2

Requêtes qui peuvent violer la clé étrangère `R.B -> S.B` :

- `INSERT` dans `R` avec un `B` absent de `S`.
- `UPDATE` de `R.B` vers une valeur absente de `S`.
- `DELETE` dans `S` d'une ligne référencée par `R`.
- `UPDATE` de `S.B` sur une ligne référencée par `R`.

Les deux premières (côté `R`) sont toujours rejetées : il n'y a rien à corriger, la valeur n'existe pas.

Les deux dernières (côté `S`) dépendent de la politique : set null, cascade ou reject.

Émulation :

- Côté `R`, pour les trois politiques : `before insert` et `before update` qui rejettent si `NEW.B` n'est pas `NULL` et n'existe pas dans `S`.
- Côté `S`, deux triggers (delete et update) qui changent selon la politique :

| Politique | delete sur S | update de S.B |
|---|---|---|
| set null | `update R set B = null where B = OLD.B` | idem |
| cascade | `delete from R where B = OLD.B` | `update R set B = NEW.B where B = OLD.B` |
| reject | `signal` si une ligne de `R` a `B = OLD.B` | idem |

Set null et cascade sont en `after` : on modifie `R` une fois que `S` a bien été modifiée. Reject est en `before` : on refuse avant de toucher `S`.

Dans le script les trois versions sont créées l'une après l'autre (`drop trigger` entre chaque), c'est reject qui reste à la fin.

Tests, avec `S = {1, 2}` et `R = {(10, 1), (20, 2), (30, null)}` :

```sql
insert into R values (40, 9);       -- erreur dans les 3 cas
delete from S where B = 1;          -- set null : R(10) passe à NULL / cascade : R(10) supprimé / reject : erreur
update S set B = 5 where B = 2;     -- set null : R(20) passe à NULL / cascade : R(20) passe à 5 / reject : erreur
```

## Exercice 3

```sql
constraint EMP_CK_SAL check (SAL > 0),
constraint EMP_CK_HIRED check (HIRED <= curdate()),
constraint EMP_CK_ENAME check (ENAME = upper(ENAME) and ENAME <> '')
```

Le SGBD vérifie ces contraintes à chaque `INSERT` et `UPDATE` sur `EMP`, ligne par ligne, et au moment du `ALTER TABLE` s'il y a déjà des données.

En lançant le script (MySQL 8.0) :

- a) marche, `SAL = -5` est refusé.
- b) la table n'est même pas créée : `contains disallowed function: curdate`. Une contrainte `check` doit donner toujours le même résultat, or `curdate()` change chaque jour.
- c) `'king'` est accepté. La comparaison de chaînes de MySQL ne tient pas compte de la casse, donc `'king' = 'KING'` est vrai. Il faut comparer en binaire :

```sql
constraint EMP_CK_ENAME check (cast(ENAME as binary) = cast(upper(ENAME) as binary) and ENAME <> '')
```

Avant MySQL 8.0.16, c'est pire : les `check` sont lus puis ignorés sans message.

Conclusion : un `check` ne suffit pas toujours, il faut tester. Pour b on passe par un trigger `before insert` / `before update` qui fait `signal` si `NEW.HIRED > curdate()`.

## Exercice 4

Première contrainte : elle ne porte que sur la ligne, un `check` suffit. On considère qu'un top-level manager est un employé sans chef (`MGR` à `NULL`) :

```sql
constraint EMP_CK_SAL_MAX check (SAL < 7500 or MGR is null)
```

Deuxième contrainte : elle porte sur plusieurs lignes (moyenne par département). En SQL standard ce serait une assertion :

```sql
create assertion AVG_SAL check (
    not exists (select DID from EMP group by DID having avg(SAL) > 5000)
);
```

MySQL ne connaît pas `create assertion` et n'accepte pas de sous-requête dans un `check`. Il faut des triggers `after` sur `EMP` qui recalculent la moyenne du département touché :

- `insert` : département `NEW.DID`.
- `update` : `NEW.DID` et `OLD.DID` (un employé qui change de département fait aussi bouger l'ancien).
- `delete` : `OLD.DID`. Supprimer un salaire bas peut faire monter la moyenne.

En InnoDB, une erreur dans un trigger `after` annule toute la requête.

Tests :

```sql
update EMP set SAL = 8000 where EID = 7566;     -- erreur : JONES a un chef
update EMP set SAL = 9000 where EID = 7839;     -- ok : KING n'a pas de chef
insert into EMP values (9002, 'BOB', 'CLERK', 7839, date '2020-01-01', 6000, null, 40);    -- erreur : moyenne de 40 = 6000
insert into EMP values (9002, 'BOB', 'CLERK', 7839, date '2020-01-01', 4000, null, 40);    -- ok
insert into EMP values (9003, 'ANN', 'CLERK', 7839, date '2020-01-01', 5500, null, 40);    -- ok : moyenne = 4750
delete from EMP where EID = 9002;                                                          -- erreur : moyenne passerait à 5500
```

## Exercice 5

```sql
create trigger EMP_SAL_INSERT
before insert on EMP
for each row
begin
    if NEW.SAL <= 0 then
        signal sqlstate '45000' set message_text = 'Le salaire doit etre positif';
    end if;
end $$
```

Même trigger en `before update` (`EMP_SAL_UPDATE`).

## Exercice 6

```sql
create trigger EMP_ENAME_INSERT
before insert on EMP
for each row
begin
    set NEW.ENAME = upper(NEW.ENAME);
end $$
```

Même trigger en `before update` (`EMP_ENAME_UPDATE`).

Ici on corrige au lieu de refuser : `'doe'` est enregistré `'DOE'`. Le trigger `before` passe avant le `check` de l'exercice 3, donc le `check` ne bloque plus que la chaîne vide.

## Exercice 7

```sql
create table SALHIST (
    EID     int not null,
    UDATE   date not null,
    SAL     decimal(6 , 2)
) engine=InnoDB;
```

Pas de clé étrangère vers `EMP` : l'historique doit rester après le départ de l'employé.

Trois triggers `after` sur `EMP` :

- `insert` : `(NEW.EID, NEW.HIRED, NEW.SAL)`, l'historique commence à la date d'embauche.
- `update` : `(NEW.EID, curdate(), NEW.SAL)`, seulement si `NEW.SAL <> OLD.SAL`.
- `delete` : `(OLD.EID, curdate(), null)`, le départ.

Les triggers sont créés avant les `insert` du script, donc `SALHIST` est remplie dès le départ avec le salaire d'embauche de chaque employé.

Test :

```sql
insert into EMP values (9001, 'doe', 'CLERK', 7782, date '2020-01-01', 1000, null, 10);
update EMP set SAL = 1500 where EID = 9001;
delete from EMP where EID = 9001;
select * from SALHIST where EID = 9001;
```

```
9001  2020-01-01  1000.00
9001  2026-10-06  1500.00
9001  2026-10-06  NULL
```
