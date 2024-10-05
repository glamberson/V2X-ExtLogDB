'check session and permission
' version 0.7.14.22

Public Function CheckSessionAndPermission(requiredRoleId As Long) As Boolean
    Dim cmd As ADODB.Command
    Dim rs As ADODB.Recordset
    Dim isValid As Boolean
    
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = g_conn
        .CommandText = "SELECT * FROM validate_session_and_permission(?, ?)"
        .Parameters.Append .CreateParameter("@p_session_id", adGUID, adParamInput, , g_sessionToken)
        .Parameters.Append .CreateParameter("@p_required_role_id", adInteger, adParamInput, , requiredRoleId)
    End With
    
    Set rs = cmd.Execute
    
    If Not rs.EOF Then
        isValid = rs.Fields("is_valid").Value
        If isValid Then
            g_userId = rs.Fields("user_id").Value
            g_roleId = rs.Fields("role_id").Value
        End If
    Else
        isValid = False
    
    rs.Close
    Set rs = Nothing
    Set cmd = Nothing
    
    CheckSessionAndPermission = isValid
End Function




