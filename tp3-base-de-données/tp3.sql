-- Base Company

drop table if exists SALHIST;
drop table if exists MISSION;
drop table if exists EMP;
drop table if exists DEPT;

create table DEPT (
    DID     int,
    DNAME   varchar(20) not null,
    DLOC    varchar(30) not null,
    constraint DEPT_PK primary key (DID)
) engine=InnoDB;

create table EMP (
    EID     int,
    ENAME   varchar(20) not null,
    JOB     varchar(20) not null,
    MGR     int,
    HIRED   date not null,
    SAL     decimal(6 , 2) not null,
    COMM    decimal(6 , 2),
    DID     int,
    constraint EMP_PK primary key (EID),
    constraint EMP_FK_MNGR foreign key (MGR) references EMP (EID),
    constraint EMP_FK_DID  foreign key (DID) references DEPT (DID)
) engine=InnoDB;

create table MISSION (
    MID     int,
    EID     int not null,
    CNAME   varchar(30) not null,
    MLOC    varchar(30) not null,
    ENDD    date,
    constraint MISSION_PK primary key (MID),
    constraint MISSION_FK_EID foreign key (EID) references EMP (EID)
) engine=InnoDB;

-- Données

insert into DEPT values(10, 'ACCOUNTING',	'NEW-YORK');
insert into DEPT values(20, 'RESEARCH', 	'DALLAS');
insert into DEPT values(30, 'SALES',		'CHICAGO');
insert into DEPT values(40, 'OPERATIONS',	'BOSTON');

insert into EMP values(7839, 'KING',    'PRESIDENT',    null, date '1981-11-17', 5000.00,   null,   null);
insert into EMP values(7566, 'JONES',   'MANAGER',      7839, date '1981-04-02', 2975.00,   null,   20);
insert into EMP values(7698, 'BLAKE',   'MANAGER',      7839, date '1981-05-01', 2850.00,   null,   30);
insert into EMP values(7782, 'CLARK',   'MANAGER',      7839, date '1981-06-09', 2450.00,   null,   10);
insert into EMP values(8000, 'SMITH',   'MANAGER',      7839, date '1980-12-17', 3000.00,   null,   10);
insert into EMP values(7788, 'SCOTT',   'ANALYST',      7566, date '1981-11-09', 3000.00,   null,   20);
insert into EMP values(7902, 'FORD',    'ANALYST',      7566, date '1981-12-03', 3000.00,   null,   20);
insert into EMP values(7499, 'ALLEN',   'SALESMAN',     7698, date '1981-02-20', 1600.00,   300.00, 30);
insert into EMP values(7521, 'WARD',    'SALESMAN',     7698, date '1981-02-22', 1250.00,   500.00, 30);
insert into EMP values(7654, 'MARTIN',  'SALESMAN',     7698, date '1981-09-28', 1250.00,   1400.00, 30);
insert into EMP values(7844, 'TURNER',  'SALESMAN',     7698, date '1981-09-08', 1500.00,   0.00,   30);
insert into EMP values(7900, 'JAMES',   'CLERK',        7698, date '1981-12-03', 950.00,    null,   30);
insert into EMP values(7934, 'MILLER',  'CLERK',        7782, date '1982-01-23', 1300.00,   null,   10);
insert into EMP values(7876, 'ADAMS',   'CLERK',        7788, date '1981-09-23', 1100.00,   null,   20);
insert into EMP values(7369, 'SMITH',   'CLERK',        7902, date '1980-12-17', 800.00,    null,   20);

insert into MISSION values(218, 7499, 'Decathlon',  'LYON',     date '2011-12-24');
insert into MISSION values(209, 7654, 'BMW',        'BERLIN',   date '2011-02-09');
insert into MISSION values(212, 7698, 'MacDo',      'CHICAGO',  date '2011-03-04');
insert into MISSION values(216, 7698, 'IBM',        'CHICAGO',  date '2011-02-09');
insert into MISSION values(219, 7782, 'BMW',        'CHICAGO',  date '2011-08-16');
insert into MISSION values(214, 7900, 'Fidal',      'PARIS',    date '2011-06-07');
insert into MISSION values(213, 7902, 'Oracle',     'DALLAS',   date '2011-04-11');
insert into MISSION values(220, 7369, 'IBM',        'LONDON',   date '2015-06-20');
insert into MISSION values(300, 8000, 'ECE',        'PARIS',    date '2018-06-11');

-- Exercice 1

drop table if exists R;

create table R (
    A   int,
    B   int
) engine=MyISAM;

delimiter $$

create trigger R_PK_INSERT
before insert on R
for each row
begin
    if NEW.A is null or exists (select * from R where A = NEW.A) then
        signal sqlstate '45000' set message_text = 'Cle primaire de R';
    end if;
end $$

create trigger R_PK_UPDATE
before update on R
for each row
begin
    if NEW.A is null or (NEW.A <> OLD.A and exists (select * from R where A = NEW.A)) then
        signal sqlstate '45000' set message_text = 'Cle primaire de R';
    end if;
end $$

delimiter ;

insert into R values (1, 10);
insert into R values (2, 20);

select * from R;

-- Exercice 2

drop table if exists R;
drop table if exists S;

create table S (
    B   int,
    C   int
) engine=MyISAM;

create table R (
    A   int,
    B   int
) engine=MyISAM;

-- R : B doit exister dans S

delimiter $$

create trigger R_FK_INSERT
before insert on R
for each row
begin
    if NEW.B is not null and not exists (select * from S where B = NEW.B) then
        signal sqlstate '45000' set message_text = 'B absent de S';
    end if;
end $$

create trigger R_FK_UPDATE
before update on R
for each row
begin
    if NEW.B is not null and not exists (select * from S where B = NEW.B) then
        signal sqlstate '45000' set message_text = 'B absent de S';
    end if;
end $$

delimiter ;

-- S : set null

delimiter $$

create trigger S_FK_DELETE
after delete on S
for each row
begin
    update R set B = null where B = OLD.B;
end $$

create trigger S_FK_UPDATE
after update on S
for each row
begin
    if NEW.B <> OLD.B then
        update R set B = null where B = OLD.B;
    end if;
end $$

delimiter ;

-- S : cascade

drop trigger S_FK_DELETE;
drop trigger S_FK_UPDATE;

delimiter $$

create trigger S_FK_DELETE
after delete on S
for each row
begin
    delete from R where B = OLD.B;
end $$

create trigger S_FK_UPDATE
after update on S
for each row
begin
    if NEW.B <> OLD.B then
        update R set B = NEW.B where B = OLD.B;
    end if;
end $$

delimiter ;

-- S : reject

drop trigger S_FK_DELETE;
drop trigger S_FK_UPDATE;

delimiter $$

create trigger S_FK_DELETE
before delete on S
for each row
begin
    if exists (select * from R where B = OLD.B) then
        signal sqlstate '45000' set message_text = 'B utilise dans R';
    end if;
end $$

create trigger S_FK_UPDATE
before update on S
for each row
begin
    if NEW.B <> OLD.B and exists (select * from R where B = OLD.B) then
        signal sqlstate '45000' set message_text = 'B utilise dans R';
    end if;
end $$

delimiter ;

insert into S values (1, 100);
insert into S values (2, 200);
insert into R values (10, 1);
insert into R values (20, null);

select * from S;
select * from R;

-- Exercice 3

alter table EMP add constraint EMP_CK_SAL check (SAL > 0);

-- refusé par MySQL : alter table EMP add constraint EMP_CK_HIRED check (HIRED <= curdate());

alter table EMP add constraint EMP_CK_ENAME check (cast(ENAME as binary) = cast(upper(ENAME) as binary) and ENAME <> '');

delimiter $$

create trigger EMP_HIRED_INSERT
before insert on EMP
for each row
begin
    if NEW.HIRED > curdate() then
        signal sqlstate '45000' set message_text = 'Date dans le futur';
    end if;
end $$

create trigger EMP_HIRED_UPDATE
before update on EMP
for each row
begin
    if NEW.HIRED > curdate() then
        signal sqlstate '45000' set message_text = 'Date dans le futur';
    end if;
end $$

delimiter ;

-- Exercice 4

alter table EMP add constraint EMP_CK_SAL_MAX check (SAL < 7500 or MGR is null);

delimiter $$

create trigger EMP_AVG_INSERT
after insert on EMP
for each row
begin
    if (select avg(SAL) from EMP where DID = NEW.DID) > 5000 then
        signal sqlstate '45000' set message_text = 'Moyenne > 5000';
    end if;
end $$

create trigger EMP_AVG_UPDATE
after update on EMP
for each row
begin
    if (select avg(SAL) from EMP where DID = NEW.DID) > 5000
    or (select avg(SAL) from EMP where DID = OLD.DID) > 5000 then
        signal sqlstate '45000' set message_text = 'Moyenne > 5000';
    end if;
end $$

create trigger EMP_AVG_DELETE
after delete on EMP
for each row
begin
    if (select avg(SAL) from EMP where DID = OLD.DID) > 5000 then
        signal sqlstate '45000' set message_text = 'Moyenne > 5000';
    end if;
end $$

delimiter ;

-- Exercice 5

delimiter $$

create trigger EMP_SAL_INSERT
before insert on EMP
for each row
begin
    if NEW.SAL <= 0 then
        signal sqlstate '45000' set message_text = 'Salaire <= 0';
    end if;
end $$

create trigger EMP_SAL_UPDATE
before update on EMP
for each row
begin
    if NEW.SAL <= 0 then
        signal sqlstate '45000' set message_text = 'Salaire <= 0';
    end if;
end $$

delimiter ;

-- Exercice 6

delimiter $$

create trigger EMP_ENAME_INSERT
before insert on EMP
for each row
begin
    set NEW.ENAME = upper(NEW.ENAME);
end $$

create trigger EMP_ENAME_UPDATE
before update on EMP
for each row
begin
    set NEW.ENAME = upper(NEW.ENAME);
end $$

delimiter ;

-- Exercice 7

create table SALHIST (
    EID     int not null,
    UDATE   date not null,
    SAL     decimal(6 , 2)
) engine=InnoDB;

delimiter $$

create trigger EMP_HIST_INSERT
after insert on EMP
for each row
begin
    insert into SALHIST values (NEW.EID, NEW.HIRED, NEW.SAL);
end $$

create trigger EMP_HIST_UPDATE
after update on EMP
for each row
begin
    if NEW.SAL <> OLD.SAL then
        insert into SALHIST values (NEW.EID, curdate(), NEW.SAL);
    end if;
end $$

create trigger EMP_HIST_DELETE
after delete on EMP
for each row
begin
    insert into SALHIST values (OLD.EID, curdate(), null);
end $$

delimiter ;

insert into SALHIST select EID, HIRED, SAL from EMP;

select * from EMP;
select * from SALHIST;
