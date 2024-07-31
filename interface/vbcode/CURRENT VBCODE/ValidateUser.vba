' ValidateUser
' Version 0.7.14.17

Public Function ValidateUser(username As String, password As String) As Boolean
    Dim cmd As ADODB.Command
    Dim rs As ADODB.Recordset
    Dim isValid As Boolean

    If g_conn Is Nothing Then
        InitializePostgresConnection
    End If

    Set cmd = New ADODB.Command
    cmd.ActiveConnection = g_conn
    cmd.CommandText = "SELECT * FROM login_wrapper(?, ?, ?)"
    cmd.Parameters.Append cmd.CreateParameter("@p_username", adVarChar, adParamInput, 255, username)
    cmd.Parameters.Append cmd.CreateParameter("@p_password", adVarChar, adParamInput, 255, password)
    cmd.Parameters.Append cmd.CreateParameter("@p_duration", adVarChar, adParamInput, 255, "1 hour")

    Set rs = cmd.Execute
    If Not rs.EOF Then
        g_sessionToken = rs.Fields("session_id").Value
        g_userId = rs.Fields("user_id").Value
        g_roleId = rs.Fields("role_id").Value
        isValid = Not IsNull(g_sessionToken)
    End If

    rs.Close

    ValidateUser = isValid
End Function