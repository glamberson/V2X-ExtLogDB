' Set Session Variables
' Version 0.7.14.17

Public Sub SetSessionVariables()
    Dim cmd As ADODB.Command
    Set cmd = New ADODB.Command
    cmd.ActiveConnection = g_conn
    cmd.CommandText = "SELECT set_session_variables(?, ?, ?)"
    cmd.Parameters.Append cmd.CreateParameter("@p_session_id", adGUID, adParamInput, , g_sessionToken)
    cmd.Parameters.Append cmd.CreateParameter("@p_user_id", adInteger, adParamInput, , g_userId)
    cmd.Parameters.Append cmd.CreateParameter("@p_role_id", adInteger, adParamInput, , g_roleId)
    cmd.Execute
End Sub
