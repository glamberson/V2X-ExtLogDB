' ValidateUser
' Version 0.7.13

Public Function ValidateUser(username As String, password As String) As Boolean
    Dim cmd As Object
    Dim rs As Object
    Dim result As Boolean
    Dim sessionId As String
    Dim userId As Long
    Dim roleId As Long

    g_connString = "Driver={PostgreSQL Unicode};" & _
                   "Server=your_server_address;" & _
                   "Port=5432;" & _
                   "Database=your_database_name;" & _
                   "Uid=" & username & ";" & _
                   "Pwd=" & password & ";"
    Set g_conn = CreateObject("ADODB.Connection")
    g_conn.Open g_connString
    Set cmd = CreateObject("ADODB.Command")
    cmd.ActiveConnection = g_conn
    cmd.CommandText = "SELECT user_login(?, ?, INTERVAL '1 hour')"
    cmd.Parameters.Append cmd.CreateParameter("@p_username", 200, 1, 255, username)
    cmd.Parameters.Append cmd.CreateParameter("@p_password", 200, 1, 255, password)
    Set rs = cmd.Execute
    If Not rs.EOF Then
        sessionId = rs.Fields(0).Value
        If sessionId <> "" Then
            ' Retrieve user_id and role_id using the session ID
            cmd.CommandText = "SELECT user_id, role_id FROM user_sessions WHERE session_id = ?"
            cmd.Parameters.Append cmd.CreateParameter("@p_session_id", 200, 1, 255, sessionId)
            Set rs = cmd.Execute
            If Not rs.EOF Then
                userId = rs.Fields("user_id").Value
                roleId = rs.Fields("role_id").Value
                ' Store these values in global variables or use them as needed
                result = True
            End If
        End If
    End If
    rs.Close
    Set rs = Nothing
    Set cmd = Nothing
    If Not result Then
        g_conn.Close
        Set g_conn = Nothing
    End If
    ValidateUser = result
End Function

