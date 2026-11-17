<%@ page contentType="application/json;charset=UTF-8" import="java.sql.*" trimDirectiveWhitespaces="true" %>
<%!
  // Needs the Oracle JDBC driver (ojdbc8.jar) in WEB-INF/lib. Tomcat 9+ / any Servlet 3.1+ container.
  static final String URL = "jdbc:oracle:thin:@//localhost:1521/XEPDB1", DB_USER = "college", DB_PASS = "change_me";

  static final String REGISTER_CODE = "";   // "" = anyone can register

  static String j(String s) {
    if (s == null) return "null";
    StringBuilder b = new StringBuilder("\"");
    for (char ch : s.toCharArray()) {
      if (ch == '"') b.append("\\\""); else if (ch == '\\') b.append("\\\\");
      else if (ch < 32) b.append(' '); else b.append(ch);
    }
    return b.append('"').toString();
  }
  static String err(String m) { return "{\"error\":" + j(m) + "}"; }
%>
<%
String a = request.getParameter("action"); if (a == null) a = "";
HttpSession s = request.getSession();
Integer uid = (Integer) s.getAttribute("uid");
String role = (String) s.getAttribute("role");
boolean post = "POST".equals(request.getMethod());

Class.forName("oracle.jdbc.OracleDriver");
try (Connection c = DriverManager.getConnection(URL, DB_USER, DB_PASS)) {

  if (a.equals("login")) {
    String sid = request.getParameter("student_id"), pw = request.getParameter("password");
    PreparedStatement p = c.prepareStatement("SELECT id, role FROM users WHERE student_id = ? " +
        "AND password_hash = LOWER(RAWTOHEX(STANDARD_HASH(salt || ?, 'SHA256')))");
    p.setString(1, sid == null ? "" : sid.trim()); p.setString(2, pw == null ? "" : pw);
    ResultSet r = p.executeQuery();
    if (!post || !r.next()) { response.setStatus(401); out.print(err("Invalid ID or password.")); return; }
    int newId = r.getInt(1); String newRole = r.getString(2);
    s.invalidate(); s = request.getSession(true);            // new session id after login
    s.setAttribute("uid", newId); s.setAttribute("role", newRole);
    out.print("{\"ok\":true}");

  } else if (a.equals("logout")) {
    s.invalidate(); out.print("{\"ok\":true}");

  } else if (a.equals("register")) {
    String sid = request.getParameter("student_id"), nm = request.getParameter("name"),
           pw = request.getParameter("password"), code = request.getParameter("code");
    sid = sid == null ? "" : sid.trim(); nm = nm == null ? "" : nm.trim(); pw = pw == null ? "" : pw;
    String problem = null; int status = 400;
    if (!post) { problem = "POST required."; status = 405; }
    else if (!REGISTER_CODE.isEmpty() && !REGISTER_CODE.equals(code)) { problem = "Invalid college code."; status = 403; }
    else if (!sid.matches("[A-Za-z0-9_-]{3,30}")) problem = "Student ID must be 3-30 letters, numbers, - or _.";
    else if (nm.length() < 2 || nm.length() > 100) problem = "Enter your full name.";
    else if (pw.length() < 6) problem = "Password must be at least 6 characters.";
    if (problem != null) { response.setStatus(status); out.print(err(problem)); return; }

    PreparedStatement p = c.prepareStatement("SELECT 1 FROM users WHERE student_id = ?");
    p.setString(1, sid);
    if (p.executeQuery().next()) { response.setStatus(409); out.print(err("That student ID is already registered.")); return; }
    byte[] raw = new byte[8]; new java.security.SecureRandom().nextBytes(raw);
    StringBuilder salt = new StringBuilder(); for (byte x : raw) salt.append(String.format("%02x", x));
    p = c.prepareStatement("INSERT INTO users (student_id, name, salt, password_hash, role) " +
        "VALUES (?, ?, ?, LOWER(RAWTOHEX(STANDARD_HASH(? || ?, 'SHA256'))), 'student')");
    p.setString(1, sid); p.setString(2, nm); p.setString(3, salt.toString()); p.setString(4, salt.toString()); p.setString(5, pw);
    p.executeUpdate();
    out.print("{\"ok\":true}");

  } else if (uid == null) {
    response.setStatus(401); out.print(err("Please log in first."));

  } else if (a.equals("me")) {
    PreparedStatement p = c.prepareStatement("SELECT student_id, name, has_voted FROM users WHERE id = ?");
    p.setInt(1, uid); ResultSet r = p.executeQuery(); r.next();
    ResultSet e = c.createStatement().executeQuery("SELECT title, is_open FROM election WHERE id = 1"); e.next();
    out.print("{\"user\":{\"student_id\":" + j(r.getString(1)) + ",\"name\":" + j(r.getString(2)) + ",\"role\":" + j(role) +
        "},\"has_voted\":" + (r.getInt(3) == 1) + ",\"election\":{\"title\":" + j(e.getString(1)) + ",\"is_open\":" + e.getInt(2) + "}}");

  } else if (a.equals("candidates")) {
    ResultSet r = c.createStatement().executeQuery("SELECT id, name, post, department, manifesto FROM candidates ORDER BY post, name");
    StringBuilder b = new StringBuilder("[");
    while (r.next()) {
      if (b.length() > 1) b.append(',');
      b.append("{\"id\":").append(r.getInt(1)).append(",\"name\":").append(j(r.getString(2)))
       .append(",\"post\":").append(j(r.getString(3))).append(",\"department\":").append(j(r.getString(4)))
       .append(",\"manifesto\":").append(j(r.getString(5))).append('}');
    }
    out.print(b.append(']'));

  } else if (a.equals("vote")) {
    if (!post) { response.setStatus(405); out.print(err("POST required.")); return; }
    if ("admin".equals(role)) { response.setStatus(403); out.print(err("Administrators cannot vote.")); return; }
    ResultSet e = c.createStatement().executeQuery("SELECT is_open FROM election WHERE id = 1"); e.next();
    if (e.getInt(1) != 1) { response.setStatus(403); out.print(err("Voting is closed.")); return; }
    int cid = 0;
    try { cid = Integer.parseInt(request.getParameter("candidate_id")); } catch (Exception ignore) { }

    c.setAutoCommit(false);
    PreparedStatement p = c.prepareStatement("SELECT has_voted FROM users WHERE id = ? FOR UPDATE");
    p.setInt(1, uid); ResultSet r = p.executeQuery(); r.next();
    if (r.getInt(1) == 1) { c.rollback(); response.setStatus(409); out.print(err("You have already voted.")); return; }
    p = c.prepareStatement("SELECT COUNT(*) FROM candidates WHERE id = ?");
    p.setInt(1, cid); r = p.executeQuery(); r.next();
    if (r.getInt(1) == 0) { c.rollback(); response.setStatus(400); out.print(err("Invalid candidate.")); return; }
    p = c.prepareStatement("INSERT INTO votes (candidate_id) VALUES (?)"); p.setInt(1, cid); p.executeUpdate();
    p = c.prepareStatement("UPDATE users SET has_voted = 1 WHERE id = ?"); p.setInt(1, uid); p.executeUpdate();
    c.commit();
    out.print("{\"ok\":true}");

  } else if (a.equals("results")) {
    ResultSet e = c.createStatement().executeQuery("SELECT is_open FROM election WHERE id = 1"); e.next();
    if (!"admin".equals(role) && e.getInt(1) == 1) { response.setStatus(403); out.print(err("Results are shown after voting closes.")); return; }
    ResultSet r = c.createStatement().executeQuery("SELECT c.id, c.name, c.post, COUNT(v.id) AS total FROM candidates c " +
        "LEFT JOIN votes v ON v.candidate_id = c.id GROUP BY c.id, c.name, c.post ORDER BY total DESC");
    StringBuilder b = new StringBuilder("[");
    while (r.next()) {
      if (b.length() > 1) b.append(',');
      b.append("{\"id\":").append(r.getInt(1)).append(",\"name\":").append(j(r.getString(2)))
       .append(",\"post\":").append(j(r.getString(3))).append(",\"votes\":").append(r.getInt(4)).append('}');
    }
    out.print(b.append(']'));

  } else {
    response.setStatus(404); out.print(err("Unknown action."));
  }
} catch (Exception ex) {
  application.log("voting api error", ex);
  response.setStatus(500); out.print(err("Server error."));
}
%>
