<?php
// '' = anyone can register. (If you set a code, also add a "code" input to the register form in index.html.)
const REGISTER_CODE = '';
const DB_HOST = 'localhost', DB_NAME = 'college_voting', DB_USER = 'root', DB_PASS = '';

function db(): PDO {
    static $pdo = null;
    if (!$pdo) {
        $pdo = new PDO('mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4', DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $pdo;
}
