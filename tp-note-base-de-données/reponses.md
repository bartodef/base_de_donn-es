# TP noté, bases de données avancées

Fichiers :

- database.sql : le script fourni, pas modifié
- partie1.sql : les requêtes de la partie 1
- suppliers2.sql : le script modifié pour la base Suppliers2
- partie2.sql : les tests de la question 1, la table de log et le trigger de la question 2
- partie3.sql : les scénarios de transactions

# Partie 1

## Requête 1

Les clients qui n'ont commandé que des produits venant d'un autre pays que le leur.

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

Le client doit avoir au moins une commande, sinon un client sans commande sortirait aussi. Ensuite on cherche une commande qui n'est pas étrangère : produit du même pays, ou pays inconnu. Si le pays du client ou du produit est null, on ne peut pas dire que le produit est étranger, donc le client n'est pas gardé.

Résultat : Jones et Smith.

## Requête 2

Les clients qui ont commandé tous les produits à moins de 5 dollars.

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

C'est une division : on garde le client s'il n'existe aucun produit à moins de 5 dollars qu'il n'a pas commandé. Le chocolat à 5.0 n'est pas pris car la condition est strictement inférieure.

Résultat : Jones, Blake, Dupond et Smith.

## Requête 3

Les clients qui habitent dans le même pays qu'un client nommé Smith, sans les Smith.

```sql
select c.cid, c.cname, c.residence
from customers c
where c.cname <> 'Smith'
  and c.residence in (select s.residence
                      from customers s
                      where s.cname = 'Smith');
```

Il peut y avoir plusieurs Smith, d'où le in. Un client sans pays (null) n'est jamais gardé.

Résultat : aucune ligne, car Smith est le seul client de Great Britain. La requête a été testée avec un deuxième Smith en France : elle renvoie bien Dupond.

## Requête 4

Les produits dont le montant moyen par commande est le plus élevé. Le montant d'une commande est le prix multiplié par la quantité.

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

On n'utilise pas limit 1 : s'il y a des ex aequo, ils sont tous affichés. Un produit jamais commandé n'a pas de moyenne et n'apparaît pas.

Résultat : tea, avec 24.

## Requête 5

Les paires de clients qui ont commandé le même produit en 2014.

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

Les deux commandes doivent être de 2014. Le distinct enlève les doublons quand un client a commandé le même produit plusieurs fois en 2014, par exemple Jones et le sucre.

Résultat : 16 lignes.

# Partie 2

## Question 1

Dans suppliers2.sql, les tables sont en InnoDB et les clés étrangères de orders ont on delete restrict et on update restrict :

```sql
constraint orders_fk_pid foreign key (pid) references products (pid)
    on delete restrict on update restrict,
constraint orders_fk_cid foreign key (cid) references customers (cid)
    on delete restrict on update restrict
```

- supprimer un client qui a des commandes est refusé, même si on supprime plusieurs clients d'un coup
- modifier l'id d'un client qui a des commandes est refusé
- ajouter une commande avec un produit ou un client qui n'existe pas est refusé

Modifier le nom ou le pays d'un client reste possible, car orders ne dépend que de l'id.

Tests (partie2.sql) :

- delete from customers where cid = 1 : erreur 1451
- update customers set cid = 100 where cid = 1 : erreur 1451
- insert into orders values (99, 1, ...) : erreur 1452
- insert into orders values (1, 99, ...) : erreur 1452
- supprimer un client sans commande : accepté
- ajouter une commande correcte : accepté

## Question 2

```sql
create table customer_residence_log (
    log_id          int auto_increment,
    customer_id     int not null,
    old_residence   varchar(50),
    new_residence   varchar(50),
    constraint customer_residence_log_pk primary key (log_id)
) engine=InnoDB;

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

MySQL et MariaDB ne permettent pas de faire un trigger seulement sur une colonne. Le trigger se déclenche sur tout update de customers et vérifie lui-même que la résidence a changé. On utilise <=> au lieu de <> pour que le passage de null à un pays, ou d'un pays à null, soit aussi enregistré.

Pas de clé étrangère vers customers, sinon on ne pourrait plus supprimer un client qui a un historique.

Test :

```sql
update customers set residence = 'Germany' where cid = 1;
update customers set residence = 'Italy' where cid = 2;
update customers set residence = null where cid = 3;
update customers set cname = 'JONES' where cid = 1;
select * from customer_residence_log;
```

Résultat : 3 lignes dans le log (USA vers Germany, null vers Italy, France vers null). Le changement de nom n'est pas enregistré.

# Partie 3

Il faut deux sessions ouvertes en même temps : deux consoles mariadb, ou deux sessions dans HeidiSQL ou Workbench. phpMyAdmin ne marche pas, il ne garde pas la transaction ouverte. Les étapes sont numérotées dans partie3.sql.

## Tâche 1

Une lecture fantôme, c'est quand une transaction relance la même requête et voit des lignes en plus, ajoutées entre temps par une autre transaction.

En READ COMMITTED, A lit les clients en France (Dupond), B ajoute Martin en France, A relance la même requête et voit Dupond et Martin. C'est une lecture fantôme.

En SERIALIZABLE, A pose des verrous sur ce qu'elle lit. L'insert de B reste bloqué jusqu'à la fin de A, et A voit toujours la même chose. Le phénomène n'existe plus.

## Tâche 2

En REPEATABLE READ, l'insert de B passe tout de suite. A relit et voit toujours 2 lignes, car elle lit une photo de la base prise à sa première lecture. Mais quand A fait un update sur les commandes du produit 1, l'update modifie 3 lignes, y compris celle de B, et la ligne de B apparaît ensuite dans le select de A. La photo protège les simples lectures, pas les écritures.

Avec MariaDB 11.6 et plus, c'est différent : l'update de A est refusé avec l'erreur 1020 (Record has changed since last read) et la transaction de A est annulée. MariaDB préfère arrêter A plutôt que de lui faire voir une ligne qui n'était pas dans sa photo. Il n'y a pas de fantôme, mais A doit tout recommencer.

En SERIALIZABLE, l'insert de B est bloqué dès que A a lu les commandes du produit 1. A voit 2 lignes du début à la fin, et son update ne modifie que 2 lignes. B ne continue que quand A a fini.

Différence : REPEATABLE READ ne bloque pas les autres transactions et donne de bonnes performances, mais si la transaction écrit, une ligne fantôme peut apparaître (MySQL, MariaDB avant 11.6) ou la transaction est annulée (MariaDB 11.6 et plus). SERIALIZABLE évite tous les fantômes, mais les autres transactions doivent attendre, avec un risque d'attente trop longue (erreur après 50 secondes) ou de blocage mutuel.
