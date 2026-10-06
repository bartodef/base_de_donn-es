-- 5)

DROP VIEW IF EXISTS student_courses_view;
DROP VIEW IF EXISTS student_years_view;

DROP TABLE IF EXISTS Enrollments;
DROP TABLE IF EXISTS Courses;
DROP TABLE IF EXISTS Students;

CREATE TABLE Students (
    studentId   CHAR(9),
    lastName    VARCHAR(30),
    firstName   VARCHAR(30),
    schoolYear  INT,
    CONSTRAINT pk_students PRIMARY KEY (studentId)
);

CREATE TABLE Courses (
    courseCode  VARCHAR(20),
    courseName  VARCHAR(50),
    schoolYear  INT,
    duration    INT,
    CONSTRAINT pk_courses PRIMARY KEY (courseCode),
    CONSTRAINT uq_courses_name UNIQUE (courseName)
);

CREATE TABLE Enrollments (
    studentId   CHAR(9),
    courseCode  VARCHAR(20),
    finalGrade  DECIMAL(4,2),
    CONSTRAINT pk_enrollments PRIMARY KEY (studentId, courseCode),
    CONSTRAINT fk_enrollments_students FOREIGN KEY (studentId) REFERENCES Students(studentId),
    CONSTRAINT fk_enrollments_courses FOREIGN KEY (courseCode) REFERENCES Courses(courseCode)
);

INSERT INTO Students VALUES ('123456789', 'DUPONT', 'Salim', 4);

INSERT INTO Courses VALUES ('INGPA-INF4000-13', 'Databases', 4, 27);

INSERT INTO Enrollments VALUES ('123456789', 'INGPA-INF4000-13', 18);

SELECT * FROM Students;
SELECT * FROM Courses;
SELECT * FROM Enrollments;


-- 6.1)

INSERT INTO Students VALUES ('987654321', 'MARTIN', 'Lea', NULL);

INSERT INTO Students (studentId, lastName, firstName) VALUES ('987654322', 'BERNARD', 'Paul');

SELECT * FROM Students;


-- 6.2)

UPDATE Courses SET duration = 30 WHERE courseCode = 'INGPA-INF4000-13';

SELECT * FROM Courses WHERE courseCode = 'INGPA-INF4000-13';


-- 6.3)

UPDATE Courses SET courseName = 'Advanced Databases' WHERE courseCode = 'INGPA-INF4000-13';

SELECT * FROM Courses WHERE courseCode = 'INGPA-INF4000-13';


-- 8)

ALTER TABLE Enrollments ADD courseWorkGrade DECIMAL(4,2);

SELECT * FROM Enrollments;


-- 9.1)

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


-- 9.2)

CREATE VIEW student_years_view AS
SELECT firstName, lastName, schoolYear
FROM Students;

UPDATE student_years_view
SET schoolYear = 5
WHERE lastName = 'DUPONT' AND firstName = 'Salim';

SELECT * FROM Students WHERE lastName = 'DUPONT' AND firstName = 'Salim';


-- 9.3)

DROP VIEW student_courses_view;

CREATE VIEW student_courses_view AS
SELECT S.firstName, S.lastName, C.courseName, C.duration, E.finalGrade
FROM Students S, Enrollments E, Courses C
WHERE S.studentId = E.studentId
  AND E.courseCode = C.courseCode;

SELECT * FROM student_courses_view;


-- 9.4)

DROP VIEW student_courses_view;
DROP VIEW student_years_view;
