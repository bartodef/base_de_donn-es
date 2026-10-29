use Suppliers;

-- Requête 1

select c.cid, c.cname
from customers c
where exists (select * from orders o where o.cid = c.cid)
  and not exists (select *
                  from orders o, products p
                  where o.pid = p.pid
                    and o.cid = c.cid
                    and (p.origin = c.residence or p.origin is null or c.residence is null));


-- Requête 2

select c.cid, c.cname
from customers c
where not exists (select *
                  from products p
                  where p.price < 5
                    and not exists (select *
                                    from orders o
                                    where o.cid = c.cid
                                      and o.pid = p.pid));


-- Requête 3

select c.cid, c.cname, c.residence
from customers c
where c.cname <> 'Smith'
  and c.residence in (select s.residence
                      from customers s
                      where s.cname = 'Smith');


-- Requête 4

select p.pid, p.pname, avg(p.price * o.quantity) as montant_moyen
from products p, orders o
where p.pid = o.pid
group by p.pid, p.pname
having avg(p.price * o.quantity) >= all (select avg(p2.price * o2.quantity)
                                         from products p2, orders o2
                                         where p2.pid = o2.pid
                                         group by p2.pid);


-- Requête 5

select distinct c1.cname as cname1, c2.cname as cname2, p.pname
from orders o1, orders o2, customers c1, customers c2, products p
where o1.pid = o2.pid
  and o1.cid = c1.cid
  and o2.cid = c2.cid
  and o1.pid = p.pid
  and year(o1.odate) = 2014
  and year(o2.odate) = 2014
  and c1.cname < c2.cname;
