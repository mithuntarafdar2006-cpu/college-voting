-- Oracle 12c+ (needs identity columns and STANDARD_HASH). Run as the application schema user.
CREATE TABLE users (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id    VARCHAR2(30)  NOT NULL UNIQUE,
  name          VARCHAR2(100) NOT NULL,
  salt          VARCHAR2(32)  NOT NULL,
  password_hash CHAR(64)      NOT NULL,
  role          VARCHAR2(10)  DEFAULT 'student' NOT NULL CHECK (role IN ('student','admin')),
  has_voted     NUMBER(1)     DEFAULT 0 NOT NULL
);

CREATE TABLE candidates (
  id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(100) NOT NULL,
  post       VARCHAR2(80)  NOT NULL,
  department VARCHAR2(80),
  manifesto  VARCHAR2(500)
);

CREATE TABLE votes (
  id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  candidate_id NUMBER NOT NULL REFERENCES candidates(id) ON DELETE CASCADE
);

CREATE TABLE election (
  id      NUMBER(1) PRIMARY KEY,
  title   VARCHAR2(150) NOT NULL,
  is_open NUMBER(1) DEFAULT 0 NOT NULL
);

INSERT INTO election VALUES (1, 'Student Council Election 2026', 1);

-- Demo accounts: admin / admin123   and   S1001 / student123
INSERT INTO users (student_id, name, salt, password_hash, role) VALUES
 ('admin', 'Election Admin', 'a1b2', LOWER(RAWTOHEX(STANDARD_HASH('a1b2'||'admin123','SHA256'))),   'admin');
INSERT INTO users (student_id, name, salt, password_hash, role) VALUES
 ('S1001', 'Demo Student',   'c3d4', LOWER(RAWTOHEX(STANDARD_HASH('c3d4'||'student123','SHA256'))), 'student');
INSERT INTO users (student_id, name, salt, password_hash, role) VALUES
 ('S1002', 'Second Student', 'e5f6', LOWER(RAWTOHEX(STANDARD_HASH('e5f6'||'student123','SHA256'))), 'student');

INSERT INTO candidates (name, post, department, manifesto) VALUES
 ('Aarav Sharma', 'President', 'Computer Science', 'Longer library hours, a student-run job board, and open budget meetings.');
INSERT INTO candidates (name, post, department, manifesto) VALUES
 ('Meera Das', 'President', 'Commerce', 'Better canteen options, free exam-prep workshops, and a fair grievance desk.');
INSERT INTO candidates (name, post, department, manifesto) VALUES
 ('Rohan Ghosh', 'President', 'Mechanical Eng.', 'Upgraded labs, more sports funding, and a monthly town hall with the principal.');
COMMIT;
