# TP Bases de données — Réponses

## 1)

```
Students(lastName, firstName, schoolYear)
    PK (lastName, firstName)

Courses(courseName, schoolYear, duration)
    PK (courseName)

Enrollments(lastName, firstName, courseName, finalGrade)
    PK (lastName, firstName, courseName)
    FK (lastName, firstName) -> Students(lastName, firstName)
    FK (courseName)          -> Courses(courseName)
```

Un étudiant dans plusieurs cours : plusieurs tuples de `Enrollments` avec le même `(lastName, firstName)`.

Un cours sans étudiant : aucun tuple de `Enrollments` ne référence son `courseName`.

La relation N-N est portée par `Enrollments`. `finalGrade` dépend du couple étudiant-cours, donc il est dans `Enrollments`.

## 2)

```
Students(studentId, lastName, firstName, schoolYear)
    PK (studentId)

Courses(courseCode, courseName, schoolYear, duration)
    PK (courseCode)
    UNIQUE (courseName)

Enrollments(studentId, courseCode, finalGrade)
    PK (studentId, courseCode)
    FK (studentId)  -> Students(studentId)
    FK (courseCode) -> Courses(courseCode)
```

## 3)

| Critère | Modèle 1 | Modèle 2 | Gagnant |
|---|---|---|---|
| Espace disque | 3 chaînes longues par inscription | 2 clés courtes par inscription | 2 |
| Requête « cours de Salim Dupond » | 1 table à lire, le nom du cours est dans `Enrollments` | jointure `Students` → `Enrollments` → `Courses` | 1 |
| Renommer « Databases » | nom dupliqué dans `Enrollments`, à propager partout | 1 `UPDATE` sur 1 ligne de `Courses` | 2 |

Le modèle 2 gagne : les jointures en plus portent sur des clés courtes et indexées, alors que la redondance du modèle 1 provoque une anomalie de mise à jour à chaque renommage.

## 4)

```sql
CREATE TABLE Students (
    studentId   CHAR(9),
    lastName    VARCHAR(30),
    firstName   VARCHAR(30),
    schoolYear  INT
);

CREATE TABLE Courses (
    courseCode  VARCHAR(20),
    courseName  VARCHAR(50),
    schoolYear  INT,
    duration    INT
);

CREATE TABLE Enrollments (
    studentId   CHAR(9),
    courseCode  VARCHAR(20),
    finalGrade  DECIMAL(4,2)
);

INSERT INTO Students VALUES ('123456789', 'DUPONT', 'Salim', 4);
INSERT INTO Courses VALUES ('INGPA-INF4000-13', 'Databases', 4, 27);
INSERT INTO Enrollments VALUES ('123456789', 'INGPA-INF4000-13', 18);

SELECT * FROM Students;
SELECT * FROM Courses;
SELECT * FROM Enrollments;
```

Les clés sont des contraintes d'intégrité, pas une condition de fonctionnement. Sans elles le SGBD stocke et restitue tout ce qu'on lui donne, sans vérifier ni l'unicité, ni les `NULL`, ni l'existence des tuples référencés. La cohérence repose alors sur l'application.

## 5)

Script : `school.sql`.

Création : `Students`, `Courses`, puis `Enrollments`. Une FK exige que la table cible et sa clé existent déjà. Impossible en cas de cycle de références : il faut créer les tables sans FK, puis les ajouter par `ALTER TABLE … ADD CONSTRAINT …`.

Suppression : l'inverse, `Enrollments` d'abord. Une table encore référencée ne peut pas être supprimée. Un cycle bloque aussi : détruire les contraintes avant, ou désactiver la vérification.

Insertion : le référencé avant le référençant, donc l'étudiant et le cours avant l'inscription. Impossible si deux tables se référencent mutuellement avec des FK `NOT NULL` : contraintes différées (`DEFERRABLE INITIALLY DEFERRED`) ou insertion en deux temps.

Les `DROP` en tête rendent le script rejouable : exécuté plusieurs fois, il recrée et repeuple les tables à l'identique.

## 6.1)

```sql
INSERT INTO Students VALUES ('987654321', 'MARTIN', 'Lea', NULL);
INSERT INTO Students (studentId, lastName, firstName) VALUES ('987654322', 'BERNARD', 'Paul');
SELECT * FROM Students;
```

Méthode 1 : `NULL` explicite. Méthode 2 : colonne omise, le SGBD met la valeur `DEFAULT`, donc `NULL` ici.

## 6.2)

```sql
UPDATE Courses SET duration = 30 WHERE courseCode = 'INGPA-INF4000-13';
SELECT * FROM Courses WHERE courseCode = 'INGPA-INF4000-13';
```

## 6.3)

```sql
UPDATE Courses SET courseName = 'Advanced Databases' WHERE courseCode = 'INGPA-INF4000-13';
SELECT * FROM Courses WHERE courseCode = 'INGPA-INF4000-13';
```

Le renommage ne casse aucune inscription : `Enrollments` référence le code, pas le nom.

## 7.A) Clé primaire sur Students

### 7.A.1)

```sql
INSERT INTO Students VALUES ('123456789', 'DUPONT', 'Salim', 4);
INSERT INTO Students VALUES (NULL, 'DURAND', 'Alice', 2);
```

Doublon → violation d'unicité (`Duplicate entry '123456789' for key 'PRIMARY'`) : deux tuples ne peuvent pas partager la valeur de la clé primaire.

ID `NULL` → violation de `NOT NULL` : une PK est implicitement `NOT NULL`, elle doit identifier le tuple de façon certaine et `NULL` signifie « valeur inconnue ».

### 7.A.2)

```sql
ALTER TABLE Students DROP CONSTRAINT pk_students;

INSERT INTO Students VALUES ('123456789', 'DUPONT', 'Salim', 4);
INSERT INTO Students VALUES (NULL, 'DURAND', 'Alice', 2);
SELECT * FROM Students;
```

Les deux passent. Plus de contrainte, plus de vérification : la table contient le doublon et le tuple à ID `NULL`.

### 7.A.3)

```sql
ALTER TABLE Students ADD CONSTRAINT pk_students PRIMARY KEY (studentId);
```

Échec : le SGBD valide la contrainte sur l'instance courante, qui viole l'unicité et la non-nullité. Une contrainte ne s'ajoute que si les données existantes la respectent déjà.

### 7.A.4)

```sql
DELETE FROM Students WHERE studentId IS NULL;
DELETE FROM Students WHERE studentId = '123456789';
INSERT INTO Students VALUES ('123456789', 'DUPONT', 'Salim', 4);

ALTER TABLE Students ADD CONSTRAINT pk_students PRIMARY KEY (studentId);
```

Les deux lignes du doublon sont identiques sur tous les attributs : on les supprime toutes les deux et on réinsère une fois. Sinon, les distinguer par `ROWID` (Oracle, SQLite) ou `ctid` (PostgreSQL).

## 7.B) Clé étrangère de Enrollments vers Students

### 7.B.1)

```sql
INSERT INTO Enrollments VALUES (NULL, 'INGPA-INF4000-13', 12);
INSERT INTO Enrollments VALUES ('000000000', 'INGPA-INF4000-13', 12);
```

Le `NULL` est rejeté, mais pas par la FK : `studentId` fait partie de la PK de `Enrollments`, donc `NOT NULL`. Une FK seule accepte `NULL` — un `NULL` ne référence rien, l'intégrité référentielle est satisfaite.

`000000000` échoue sur la FK (`violates foreign key constraint "fk_enrollments_students"`) : la valeur n'existe pas dans `Students`, ce serait une inscription orpheline.

### 7.B.2)

```sql
ALTER TABLE Enrollments DROP CONSTRAINT fk_enrollments_students;

INSERT INTO Enrollments VALUES (NULL, 'INGPA-INF4000-13', 12);
INSERT INTO Enrollments VALUES ('000000000', 'INGPA-INF4000-13', 12);
SELECT * FROM Enrollments;
```

`000000000` passe maintenant : inscription vers un étudiant inexistant. Le `NULL` échoue toujours, c'est la PK qui l'interdit, pas la FK.

### 7.B.3)

```sql
ALTER TABLE Enrollments ADD CONSTRAINT fk_enrollments_students
    FOREIGN KEY (studentId) REFERENCES Students(studentId);
```

Échec : la ligne `000000000` n'a pas de tuple correspondant dans `Students`.

### 7.B.4)

```sql
DELETE FROM Enrollments WHERE studentId = '000000000';

ALTER TABLE Enrollments ADD CONSTRAINT fk_enrollments_students
    FOREIGN KEY (studentId) REFERENCES Students(studentId);
```

Ou insérer l'étudiant `000000000` dans `Students` au lieu de supprimer l'inscription.

## 8)

Dans `Enrollments` : comme `finalGrade`, la note dépend du couple (étudiant, cours). Pas besoin de recréer la table, `ALTER TABLE … ADD` conserve données et contraintes.

```sql
ALTER TABLE Enrollments ADD courseWorkGrade DECIMAL(4,2);
SELECT * FROM Enrollments;
```

Valeur par défaut du nouvel attribut : `NULL`, faute de clause `DEFAULT`. Sinon `ALTER TABLE Enrollments ADD courseWorkGrade DECIMAL(4,2) DEFAULT 0;`.

## 9.1)

```sql
CREATE VIEW student_courses_view AS
SELECT S.firstName, S.lastName, C.courseName, E.finalGrade
FROM Students S, Enrollments E, Courses C
WHERE S.studentId = E.studentId
  AND E.courseCode = C.courseCode;

SELECT * FROM student_courses_view;

SELECT SC.firstName, SC.lastName, SC.courseName
FROM student_courses_view SC, Courses C
WHERE SC.courseName = C.courseName
  AND C.schoolYear = 4;
```

La vue ne contient pas l'année du cours, la seconde requête la rejoint depuis `Courses`.

## 9.2)

```sql
CREATE VIEW student_years_view AS
SELECT firstName, lastName, schoolYear
FROM Students;

UPDATE student_years_view
SET schoolYear = 5
WHERE lastName = 'DUPONT' AND firstName = 'Salim';

SELECT * FROM Students WHERE lastName = 'DUPONT' AND firstName = 'Salim';
```

La vue est modifiable car monotable, sans agrégat ni `DISTINCT` : l'`UPDATE` est traduit en `UPDATE` sur `Students`, et le `SELECT` de contrôle montre `schoolYear = 5`. `student_courses_view` n'est pas modifiable, elle joint trois tables. Sous SQLite aucune vue n'est modifiable, il faut un trigger `INSTEAD OF UPDATE`.

## 9.3)

```sql
DROP VIEW student_courses_view;

CREATE VIEW student_courses_view AS
SELECT S.firstName, S.lastName, C.courseName, C.duration, E.finalGrade
FROM Students S, Enrollments E, Courses C
WHERE S.studentId = E.studentId
  AND E.courseCode = C.courseCode;

SELECT * FROM student_courses_view;
```

Une définition de vue ne se modifie pas par `ALTER` : `DROP` puis `CREATE`, ou `CREATE OR REPLACE VIEW`.

## 9.4)

```sql
DROP VIEW student_courses_view;
DROP VIEW student_years_view;
```

Supprimer une vue ne touche pas aux données, seule sa définition est stockée.
