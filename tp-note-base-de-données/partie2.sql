use Suppliers2;

-- Question 1 : tests
-- Les clés étrangères sont dans suppliers2.sql (on delete restrict on update restrict).
-- Lancer les requêtes une par une.

-- suppression d'un client qui a des commandes : refusée
delete from customers where cid = 1;

-- suppression de plusieurs clients dont certains ont des commandes : refusée
delete from customers where cid in (1, 2);

-- modification de l'id d'un client qui a des commandes : refusée
update customers set cid = 100 where cid = 1;

-- commande avec un produit qui n'existe pas : refusée
insert into orders values (99, 1, date '2024-01-01', 1);

-- commande avec un client qui n'existe pas : refusée
insert into orders values (1, 99, date '2024-01-01', 1);

-- client sans commande : suppression acceptée
insert into customers values (6, 'Test', 'Spain');
delete from customers where cid = 6;

-- commande correcte : acceptée
insert into orders values (1, 5, date '2024-01-01', 1);
delete from orders where pid = 1 and cid = 5 and odate = date '2024-01-01';


-- Question 2

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

-- Question 2 : test

update customers set residence = 'Germany' where cid = 1;
update customers set residence = 'Italy' where cid = 2;
update customers set residence = null where cid = 3;
update customers set cname = 'JONES' where cid = 1;

select * from customers;
select * from customer_residence_log;
