-- MySQL 5.7+ / 8.x
CREATE DATABASE IF NOT EXISTS college_voting CHARACTER SET utf8mb4;
USE college_voting;

CREATE TABLE users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  student_id    VARCHAR(30)  NOT NULL UNIQUE,
  name          VARCHAR(100) NOT NULL,
  salt          VARCHAR(32)  NOT NULL,
  password_hash CHAR(64)     NOT NULL,
  role          ENUM('student','admin') NOT NULL DEFAULT 'student',
  has_voted     TINYINT(1)   NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE candidates (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  post       VARCHAR(80)  NOT NULL,
  department VARCHAR(80),
  manifesto  VARCHAR(500)
) ENGINE=InnoDB;

-- Votes are NOT linked to users, so ballots stay secret.
CREATE TABLE votes (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  candidate_id INT NOT NULL,
  FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE election (
  id      TINYINT PRIMARY KEY,
  title   VARCHAR(150) NOT NULL,
  is_open TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

INSERT INTO election VALUES (1, 'Student Council Election 2026', 1);

-- Demo accounts: admin / admin123   and   S1001 / student123
INSERT INTO users (student_id, name, salt, password_hash, role) VALUES
 ('admin', 'Election Admin', 'a1b2', SHA2(CONCAT('a1b2','admin123'),256),   'admin'),
 ('S1001', 'Demo Student',   'c3d4', SHA2(CONCAT('c3d4','student123'),256), 'student'),
 ('S1002', 'Second Student', 'e5f6', SHA2(CONCAT('e5f6','student123'),256), 'student');

INSERT INTO candidates (name, post, department, manifesto) VALUES
 ('Aarav Sharma', 'President', 'Computer Science', 'Longer library hours, a student-run job board, and open budget meetings.'),
 ('Meera Das',    'President', 'Commerce',         'Better canteen options, free exam-prep workshops, and a fair grievance desk.'),
 ('Rohan Ghosh',  'President', 'Mechanical Eng.',  'Upgraded labs, more sports funding, and a monthly town hall with the principal.');
