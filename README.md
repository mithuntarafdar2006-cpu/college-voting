# College Online Voting System

Frontend (HTML/CSS/JS) talks to one JSON API. Pick ONE backend and set `API` at the top of `js/app.js`.

| Backend | Database | API file | Set `API` to |
|---|---|---|---|
| PHP 8+ (full: voting + admin) | MySQL | `php/api.php` | `php/api.php` |
| JSP (Tomcat 9+) | Oracle 12c+ | `jsp/api.jsp` | `jsp/api.jsp` |
| Classic ASP (IIS) | MySQL via ODBC | `asp/api.asp` | `asp/api.asp` |

## Run (PHP + MySQL, quickest)
1. `mysql -u root -p < database/mysql.sql`
2. Edit DB credentials in `php/config.php`.
3. From this folder: `php -S localhost:8000`, then open http://localhost:8000
4. Demo logins: `admin / admin123` (manage election, see live results) and `S1001 / student123` (vote).

## JSP + Oracle
Run `database/oracle.sql`, edit `URL/DB_USER/DB_PASS` in `jsp/api.jsp`, put `ojdbc8.jar` in `WEB-INF/lib`, deploy the folder to Tomcat.

## ASP + MySQL
Run `database/mysql.sql`, install MySQL Connector/ODBC, edit `CONN_STR` in `asp/api.asp`, publish the folder in IIS.

## Registration
Anyone can create an account from the login page (name, student ID, password). They are signed in automatically afterwards.
To restrict sign-ups, set `REGISTER_CODE` in `php/config.php`, `jsp/api.jsp` or `asp/api.asp` and add a `code` input to the register form in `index.html`.

## How it works
- One vote per student: `has_voted` is checked and set inside a DB transaction (`FOR UPDATE`).
- Secret ballot: the `votes` table stores only the candidate, never the voter.
- Results are hidden from students until the admin closes voting.
- All SQL is parameterised; all output is HTML-escaped.

## Before real use
- Passwords are salted SHA-256 so one SQL seed works on every backend. For production use bcrypt/Argon2 (`password_hash` in PHP).
- Registration is open, so student IDs are not verified and anyone can create an account and vote. For a real election, restrict sign-ups (see Registration) or import your official student list.
- Serve over HTTPS, change demo passwords, and add login rate-limiting.
- JSP/ASP versions include voting and results only; registration is in all three, but the admin screens (add candidate/student, open/close) are in the PHP version.
