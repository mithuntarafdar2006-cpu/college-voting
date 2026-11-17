<?php
require __DIR__ . '/config.php';
session_set_cookie_params(['httponly' => true, 'samesite' => 'Strict']);
session_start();
header('Content-Type: application/json; charset=utf-8');

function out($data, int $code = 200) { http_response_code($code); echo json_encode($data); exit; }
function need(bool $admin = false): array {
    $u = $_SESSION['user'] ?? null;
    if (!$u) out(['error' => 'Please log in first.'], 401);
    if ($admin && $u['role'] !== 'admin') out(['error' => 'Admin access required.'], 403);
    return $u;
}
function election(): array { return db()->query('SELECT title, is_open FROM election WHERE id = 1')->fetch(); }
function post_only() { if ($_SERVER['REQUEST_METHOD'] !== 'POST') out(['error' => 'POST required.'], 405); }

$pdo = null;
try {
    switch ($_GET['action'] ?? '') {

    case 'login':
        post_only();
        $st = db()->prepare('SELECT id, student_id, name, role FROM users
                             WHERE student_id = ? AND password_hash = SHA2(CONCAT(salt, ?), 256)');
        $st->execute([trim($_POST['student_id'] ?? ''), $_POST['password'] ?? '']);
        $u = $st->fetch();
        if (!$u) { sleep(1); out(['error' => 'Invalid ID or password.'], 401); }
        session_regenerate_id(true);
        $_SESSION['user'] = $u;
        out(['ok' => true]);

    case 'logout':
        session_destroy();
        out(['ok' => true]);

    case 'me':
        $u = need();
        $st = db()->prepare('SELECT has_voted FROM users WHERE id = ?');
        $st->execute([$u['id']]);
        out(['user' => $u, 'has_voted' => (bool)$st->fetchColumn(), 'election' => election()]);

    case 'candidates':
        need();
        out(db()->query('SELECT id, name, post, department, manifesto FROM candidates ORDER BY post, name')->fetchAll());

    case 'vote':
        post_only();
        $u = need();
        if ($u['role'] === 'admin') out(['error' => 'Administrators cannot vote.'], 403);
        if (!(int)election()['is_open']) out(['error' => 'Voting is closed.'], 403);
        $cid = (int)($_POST['candidate_id'] ?? 0);

        $pdo = db();
        $pdo->beginTransaction();
        $st = $pdo->prepare('SELECT has_voted FROM users WHERE id = ? FOR UPDATE');   // blocks double-submit
        $st->execute([$u['id']]);
        if ($st->fetchColumn()) { $pdo->rollBack(); out(['error' => 'You have already voted.'], 409); }
        $st = $pdo->prepare('SELECT COUNT(*) FROM candidates WHERE id = ?');
        $st->execute([$cid]);
        if (!$st->fetchColumn()) { $pdo->rollBack(); out(['error' => 'Invalid candidate.'], 400); }
        $pdo->prepare('INSERT INTO votes (candidate_id) VALUES (?)')->execute([$cid]);
        $pdo->prepare('UPDATE users SET has_voted = 1 WHERE id = ?')->execute([$u['id']]);
        $pdo->commit();
        out(['ok' => true]);

    case 'results':
        $u = need();
        if ($u['role'] !== 'admin' && (int)election()['is_open'])
            out(['error' => 'Results are shown after voting closes.'], 403);
        out(db()->query('SELECT c.id, c.name, c.post, COUNT(v.id) AS votes
                         FROM candidates c LEFT JOIN votes v ON v.candidate_id = c.id
                         GROUP BY c.id, c.name, c.post ORDER BY votes DESC')->fetchAll());

    case 'register':
        post_only();
        $sid = trim($_POST['student_id'] ?? ''); $n = trim($_POST['name'] ?? ''); $pw = $_POST['password'] ?? '';
        if (REGISTER_CODE !== '' && !hash_equals(REGISTER_CODE, (string)($_POST['code'] ?? ''))) out(['error' => 'Invalid college code.'], 403);
        if (!preg_match('/^[A-Za-z0-9_-]{3,30}$/', $sid)) out(['error' => 'Student ID must be 3-30 letters, numbers, - or _.'], 400);
        if (mb_strlen($n) < 2 || mb_strlen($n) > 100) out(['error' => 'Enter your full name.'], 400);
        if (strlen($pw) < 6) out(['error' => 'Password must be at least 6 characters.'], 400);
        $st = db()->prepare('SELECT 1 FROM users WHERE student_id = ?'); $st->execute([$sid]);
        if ($st->fetchColumn()) out(['error' => 'That student ID is already registered.'], 409);
        $salt = bin2hex(random_bytes(8));
        db()->prepare("INSERT INTO users (student_id, name, salt, password_hash, role)
                       VALUES (?, ?, ?, SHA2(CONCAT(?, ?), 256), 'student')")->execute([$sid, $n, $salt, $salt, $pw]);
        out(['ok' => true]);

    // ---- admin only ----
    case 'toggle_election':
        post_only(); need(true);
        db()->exec('UPDATE election SET is_open = 1 - is_open WHERE id = 1');
        out(election());

    case 'add_candidate':
        post_only(); need(true);
        $n = trim($_POST['name'] ?? ''); $p = trim($_POST['post'] ?? '');
        if ($n === '' || $p === '') out(['error' => 'Name and post are required.'], 400);
        db()->prepare('INSERT INTO candidates (name, post, department, manifesto) VALUES (?,?,?,?)')
            ->execute([$n, $p, trim($_POST['department'] ?? ''), mb_substr(trim($_POST['manifesto'] ?? ''), 0, 500)]);
        out(['ok' => true]);

    case 'add_student':
        post_only(); need(true);
        $sid = trim($_POST['student_id'] ?? ''); $n = trim($_POST['name'] ?? ''); $pw = $_POST['password'] ?? '';
        if ($sid === '' || $n === '' || strlen($pw) < 6) out(['error' => 'ID, name and a password of 6+ characters are required.'], 400);
        $salt = bin2hex(random_bytes(8));
        db()->prepare("INSERT INTO users (student_id, name, salt, password_hash, role)
                       VALUES (?, ?, ?, SHA2(CONCAT(?, ?), 256), 'student')")->execute([$sid, $n, $salt, $salt, $pw]);
        out(['ok' => true]);

    default:
        out(['error' => 'Unknown action.'], 404);
    }
} catch (PDOException $e) {
    if ($pdo && $pdo->inTransaction()) $pdo->rollBack();
    if ($e->getCode() === '23000') out(['error' => 'That record already exists.'], 409);
    error_log($e);
    out(['error' => 'Server error.'], 500);
} catch (Throwable $e) {
    error_log($e);
    out(['error' => 'Server error.'], 500);
}
