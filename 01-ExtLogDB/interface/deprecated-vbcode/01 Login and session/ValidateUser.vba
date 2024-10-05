' ValidateUser
' Version 0.7.6.4
Public Function ValidateUser(username As String, password As String) As Boolean
    Dim conn As ADODB.Connection
    Dim cmd As ADODB.Command
    Dim rs As ADODB.Recordset
    Dim isValid As Boolean
    Dim tempSessionToken As Variant

    On Error GoTo ErrorHandler

    Set conn = CreatePostgresConnection()

    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = conn
        .CommandType = adCmdText
        .CommandText = "SELECT login_wrapper(?, ?, ?)"
        .Parameters.Append .CreateParameter("@p_username", adVarChar, adParamInput, 255, username)
        .Parameters.Append .CreateParameter("@p_password", adVarChar, adParamInput, 255, password)
        .Parameters.Append .CreateParameter("@p_duration", adVarChar, adParamInput, 50, "1 hour")
    End With

    Set rs = cmd.Execute

    If Not rs.EOF Then
        tempSessionToken = rs.Fields(0).Value
        If Not IsNull(tempSessionToken) Then
            g_sessionToken = CStr(tempSessionToken)
            isValid = True
        Else
            g_sessionToken = ""
            isValid = False
        End If
    Else
        g_sessionToken = ""
        isValid = False
    End If
    
    rs.Close
    conn.Close

    ValidateUser = isValid
    Exit Function

ErrorHandler:
    Debug.Print "Error in ValidateUser: " & Err.Description & " (Error " & Err.Number & ")"
    MsgBox "Error during login: " & Err.Description, vbExclamation
    g_sessionToken = ""
    ValidateUser = False
    If Not rs Is Nothing Then
        If rs.State = adStateOpen Then rs.Close
    End If
    If Not conn Is Nothing Then
        If conn.State = adStateOpen Then conn.Close
    End If
End Function