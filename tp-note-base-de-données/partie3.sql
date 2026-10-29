-- Partie 3 : transactions
--
-- Il faut deux sessions ouvertes en même temps sur la base Suppliers :
-- deux consoles mysql, ou deux connexions dans MySQL Workbench
-- (deux onglets de la même connexion partagent la même session, ça ne marche pas).
--
-- On exécute les étapes dans l'ordre indiqué, en passant d'une session à l'autre.
-- Quand une session attend un verrou, MySQL abandonne au bout de 50 secondes :
-- il faut donc enchaîner les étapes assez vite.


-- ============================================================
-- Tâche 1 : lecture fantôme
-- ============================================================

-- 1.a) Le phénomène, en READ COMMITTED

-- Session A, étape 1 : on lit les clients qui habitent en France
use Suppliers;
set session transaction isolation level read committed;
start transaction;
select * from customers where residence = 'France';      -- 1 ligne : Dupond

-- Session B, étape 2 : on ajoute un client en France (autocommit)
use Suppliers;
insert into customers values (6, 'Martin', 'France');     -- passe tout de suite

-- Session A, étape 3 : même requête, dans la même transaction
select * from customers where residence = 'France';      -- 2 lignes : Martin est apparu, c'est une lecture fantôme
commit;

-- Session B, étape 4 : on remet la base comme avant
delete from customers where cid = 6;


-- 1.b) La solution, en SERIALIZABLE

-- Session A, étape 1
set session transaction isolation level serializable;
start transaction;
select * from customers where residence = 'France';      -- 1 ligne : Dupond

-- Session B, étape 2
insert into customers values (6, 'Martin', 'France');     -- reste bloqué : A a verrouillé ce qu'elle a lu

-- Session A, étape 3
select * from customers where residence = 'France';      -- toujours 1 ligne : pas de fantôme
commit;                                                   -- libère les verrous, l'insert de B se termine

-- Session B, étape 4
delete from customers where cid = 6;


-- ============================================================
-- Tâche 2 : REPEATABLE READ et SERIALIZABLE
-- ============================================================

-- 2.a) REPEATABLE READ (niveau par défaut de MySQL)

-- Session A, étape 1 : commandes du produit 1
set session transaction isolation level repeatable read;
start transaction;
select * from orders where pid = 1;                       -- 2 lignes

-- Session B, étape 2 : nouvelle commande du produit 1
insert into orders values (1, 5, date '2015-01-01', 1);   -- passe tout de suite, B n'est pas bloquée

-- Session A, étape 3
select * from orders where pid = 1;                       -- toujours 2 lignes : A lit une photo prise à sa première lecture

-- Session A, étape 4 : A modifie les commandes du produit 1
update orders set quantity = quantity + 1 where pid = 1;  -- 3 lignes modifiées : l'update voit la commande de B
select * from orders where pid = 1;                       -- 3 lignes : la ligne fantôme apparaît après l'update
rollback;                                                 -- on annule la modification

-- Session B, étape 5
delete from orders where pid = 1 and cid = 5 and odate = date '2015-01-01';


-- 2.b) SERIALIZABLE

-- Session A, étape 1
set session transaction isolation level serializable;
start transaction;
select * from orders where pid = 1;                       -- 2 lignes

-- Session B, étape 2
insert into orders values (1, 5, date '2015-01-01', 1);   -- reste bloqué

-- Session A, étape 3
select * from orders where pid = 1;                       -- 2 lignes
update orders set quantity = quantity + 1 where pid = 1;  -- 2 lignes modifiées seulement
select * from orders where pid = 1;                       -- 2 lignes
rollback;                                                 -- libère les verrous, l'insert de B se termine

-- Session B, étape 4
delete from orders where pid = 1 and cid = 5 and odate = date '2015-01-01';
