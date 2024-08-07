' btnLogin
' Version 0.7.14.22
Private Sub btnLogin_Click()
    Dim username As String
    Dim password As String
    
    username = Nz(Me.txtusername.Value, "")
    password = Nz(Me.txtPassword.Value, "")
    
    If Trim(username) = "" Or Trim(password) = "" Then
        MsgBox "Username and password cannot be empty.", vbExclamation
        Exit Sub
    End If
    
    If ValidateUser(username, password) Then
        MsgBox "Login successful! Session token: " & g_sessionToken
        ' Here you would typically open your main form or navigate to the main part of your application
    Else
        MsgBox "Login failed. Please check your username and password."
        
           ExecutePostgresCommand "INSERT INTO audit_trail (action, changed_by, details, changed_at) " & _
                               "VALUES ('failed_login', '" & username & "', 'Failed login.', NOW())"
    End If
End Sub