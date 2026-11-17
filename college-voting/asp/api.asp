<%@ Language="VBScript" CodePage="65001" %>
<%
' Classic ASP (IIS) + MySQL through the MySQL ODBC driver (install "MySQL Connector/ODBC 8.0").
Option Explicit
Response.ContentType = "application/json" : Response.Charset = "utf-8"
Const REGISTER_CODE = ""   ' "" = anyone can register
Const CONN_STR = "Driver={MySQL ODBC 8.0 Unicode Driver};Server=localhost;Database=college_voting;User=root;Password=;Option=3;"

Dim conn, action, uid, urole, rs, el, buf, first, cid, sid, nm, pw, salt, re
Set conn = Server.CreateObject("ADODB.Connection")
conn.Open CONN_STR

Function J(s)
  If IsNull(s) Then J = "null" : Exit Function
  s = CStr(s)
  s = Replace(s, "\", "\\") : s = Replace(s, """", "\""")
  s = Replace(s, vbCr, "") : s = Replace(s, vbLf, " ") : s = Replace(s, vbTab, " ")
  J = """" & s & """"
End Function

Sub Fail(code, msg)
  Response.Status = code & " Error"
  Response.Write "{""error"":" & J(msg) & "}"
  conn.Close : Response.End
End Sub

' Parameterised query (prevents SQL injection). args = Array(...) of values for the ? marks.
Function Run(sql, args)
  Dim cmd, i
  Set cmd = Server.CreateObject("ADODB.Command")
  Set cmd.ActiveConnection = conn
  cmd.CommandText = sql
  For i = 0 To UBound(args)
    cmd.Parameters.Append cmd.CreateParameter("p" & i, 200, 1, 255, CStr(args(i)))
  Next
  Set Run = cmd.Execute
End Function

action = Request.QueryString("action")
uid = Session("uid") : urole = Session("role")

Select Case action
Case "login"
  If Request.ServerVariables("REQUEST_METHOD") <> "POST" Then Fail 405, "POST required."
  Set rs = Run("SELECT id, role FROM users WHERE student_id = ? AND password_hash = SHA2(CONCAT(salt, ?), 256)", _
               Array(Trim(Request.Form("student_id")), Request.Form("password")))
  If rs.EOF Then Fail 401, "Invalid ID or password."
  Session("uid") = CLng(rs("id")) : Session("role") = rs("role") & ""
  Response.Write "{""ok"":true}"

Case "logout"
  Session.Abandon
  Response.Write "{""ok"":true}"

Case "register"
  If Request.ServerVariables("REQUEST_METHOD") <> "POST" Then Fail 405, "POST required."
  sid = Trim(Request.Form("student_id")) : nm = Trim(Request.Form("name")) : pw = Request.Form("password")
  If REGISTER_CODE <> "" And Request.Form("code") <> REGISTER_CODE Then Fail 403, "Invalid college code."
  Set re = New RegExp : re.Pattern = "^[A-Za-z0-9_-]{3,30}$"
  If Not re.Test(sid) Then Fail 400, "Student ID must be 3-30 letters, numbers, - or _."
  If Len(nm) < 2 Or Len(nm) > 100 Then Fail 400, "Enter your full name."
  If Len(pw) < 6 Then Fail 400, "Password must be at least 6 characters."
  Set rs = Run("SELECT id FROM users WHERE student_id = ?", Array(sid))
  If Not rs.EOF Then Fail 409, "That student ID is already registered."
  Set rs = Run("SELECT HEX(RANDOM_BYTES(8)) AS s", Array())     ' secure random salt (MySQL 5.6.17+)
  salt = rs("s") & ""
  Run "INSERT INTO users (student_id, name, salt, password_hash, role) VALUES (?, ?, ?, SHA2(CONCAT(?, ?), 256), 'student')", _
      Array(sid, nm, salt, salt, pw)
  Response.Write "{""ok"":true}"

Case Else
  If IsEmpty(uid) Then Fail 401, "Please log in first."
  Select Case action

  Case "me"
    Set rs = Run("SELECT student_id, name, has_voted FROM users WHERE id = ?", Array(uid))
    Set el = Run("SELECT title, is_open FROM election WHERE id = 1", Array())
    Response.Write "{""user"":{""student_id"":" & J(rs("student_id")) & ",""name"":" & J(rs("name")) & ",""role"":" & J(urole) & _
      "},""has_voted"":" & LCase(CStr(CInt(rs("has_voted")) <> 0)) & ",""election"":{""title"":" & J(el("title")) & _
      ",""is_open"":" & Abs(CInt(el("is_open"))) & "}}"

  Case "candidates"
    Set rs = Run("SELECT id, name, post, department, manifesto FROM candidates ORDER BY post, name", Array())
    buf = "[" : first = True
    Do While Not rs.EOF
      If Not first Then buf = buf & ","
      first = False
      buf = buf & "{""id"":" & CLng(rs("id")) & ",""name"":" & J(rs("name")) & ",""post"":" & J(rs("post")) & _
            ",""department"":" & J(rs("department")) & ",""manifesto"":" & J(rs("manifesto")) & "}"
      rs.MoveNext
    Loop
    Response.Write buf & "]"

  Case "vote"
    If Request.ServerVariables("REQUEST_METHOD") <> "POST" Then Fail 405, "POST required."
    If urole = "admin" Then Fail 403, "Administrators cannot vote."
    Set rs = Run("SELECT is_open FROM election WHERE id = 1", Array())
    If CInt(rs("is_open")) = 0 Then Fail 403, "Voting is closed."
    cid = Request.Form("candidate_id")
    If Not IsNumeric(cid) Then Fail 400, "Invalid candidate."
    conn.BeginTrans
    Set rs = Run("SELECT has_voted FROM users WHERE id = ? FOR UPDATE", Array(uid))
    If CInt(rs("has_voted")) <> 0 Then conn.RollbackTrans : Fail 409, "You have already voted."
    Set rs = Run("SELECT COUNT(*) AS n FROM candidates WHERE id = ?", Array(cid))
    If CLng(rs("n")) = 0 Then conn.RollbackTrans : Fail 400, "Invalid candidate."
    Run "INSERT INTO votes (candidate_id) VALUES (?)", Array(cid)
    Run "UPDATE users SET has_voted = 1 WHERE id = ?", Array(uid)
    conn.CommitTrans
    Response.Write "{""ok"":true}"

  Case "results"
    Set rs = Run("SELECT is_open FROM election WHERE id = 1", Array())
    If urole <> "admin" And CInt(rs("is_open")) <> 0 Then Fail 403, "Results are shown after voting closes."
    Set rs = Run("SELECT c.id, c.name, c.post, COUNT(v.id) AS total FROM candidates c " & _
                 "LEFT JOIN votes v ON v.candidate_id = c.id GROUP BY c.id, c.name, c.post ORDER BY total DESC", Array())
    buf = "[" : first = True
    Do While Not rs.EOF
      If Not first Then buf = buf & ","
      first = False
      buf = buf & "{""id"":" & CLng(rs("id")) & ",""name"":" & J(rs("name")) & ",""post"":" & J(rs("post")) & _
            ",""votes"":" & CLng(rs("total")) & "}"
      rs.MoveNext
    Loop
    Response.Write buf & "]"

  Case Else
    Fail 404, "Unknown action."
  End Select
End Select
conn.Close
%>
