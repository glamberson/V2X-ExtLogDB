' execute protected (postgres) function
' version 0.7.14.23

' Function to execute a protected PostgreSQL function
Public Function ExecuteProtectedFunction(functionName As String, ParamArray args()) As Variant
    Dim cmd As ADODB.Command
    Dim rs As ADODB.Recordset
    
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = g_conn
        .CommandText = "SELECT validate_session_and_permission(?, ?)"
        .Parameters.Append .CreateParameter("@p_session_id", adGUID, adParamInput, , g_sessionToken)
        .Parameters.Append .CreateParameter("@p_function_name", adVarChar, adParamInput, 255, functionName)
    End With
    
    Set rs = cmd.Execute
    
    Dim isValid As Boolean
    If Not rs.EOF Then
        isValid = rs.Fields("is_valid").Value
    Else
        isValid = False
    End If
    
    rs.Close
    Set rs = Nothing
    
    If Not isValid Then
        MsgBox "You don't have permission to perform this action.", vbExclamation
        Exit Function
    End If
    
    ' If we get here, the session is valid and the user has permission
    ' Now we can execute the actual function
    
    Set cmd = New ADODB.Command
    With cmd
        .ActiveConnection = g_conn
        .CommandText = "SELECT * FROM " & functionName & "(?)"
        
        ' Add session_id parameter
        .Parameters.Append .CreateParameter("@p_session_id", adGUID, adParamInput, , g_sessionToken)
        
        ' Add other parameters
        Dim i As Long
        For i = LBound(args) To UBound(args)
            .CommandText = Left(.CommandText, Len(.CommandText) - 1) & ", ?)"
            .Parameters.Append .CreateParameter("@p" & i, adVariant, adParamInput, , args(i))
        Next i
    End With
    
    On Error GoTo ErrorHandler
    
    Set rs = cmd.Execute
    
    ' Return the result
    If Not rs.EOF Then
        ExecuteProtectedFunction = rs.Fields(0).Value
    End If
    
    rs.Close
    Set rs = Nothing
    Set cmd = Nothing
    Exit Function

ErrorHandler:
    If Err.Number = 42883 Then  ' Function does not exist
        MsgBox "Function '" & functionName & "' does not exist.", vbExclamation
    Else
        MsgBox "An error occurred: " & Err.Description, vbExclamation
    End If
End Function