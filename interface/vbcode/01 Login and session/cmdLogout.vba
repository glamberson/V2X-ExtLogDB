'cmdLogout
' Version 0.7.6.1
Private Sub cmdLogout_Click()
    Dim conn As ADODB.Connection
    Dim cmd As ADODB.Command
    
    If g_sessionToken = "" Then
        MsgBox "No active session. You may already be logged out."
        Exit Sub
    End If
    
    Set conn = CreatePostgresConnection()
    
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = conn
        .CommandType = adCmdText
        .CommandText = "SELECT user_logout(?)"
        .Parameters.Append .CreateParameter("@p_session_id", adGUID, adParamInput, , g_sessionToken)
    End With
    
    On Error GoTo ErrorHandler
    
    cmd.Execute
    
    conn.Close
    
    g_sessionToken = ""  ' Clear the session token
    
    MsgBox "You have been logged out successfully."
    
    ' Here you would typically close the current form and return to the login form
    ' DoCmd.Close acForm, "YourMainFormName"
    ' DoCmd.OpenForm "LoginForm"
    Exit Sub
    
ErrorHandler:
    MsgBox "Error during logout: " & Err.Description
    conn.Close
End Sub