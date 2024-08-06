' execute postgres command
' version 0.7.14.22

Public Sub ExecutePostgresCommand(cmdText As String, ParamArray params() As Variant)
    On Error GoTo ErrorHandler
    
    Dim conn As ADODB.Connection
    Dim cmd As ADODB.Command
    Dim i As Integer

    Set conn = CreatePostgresConnection()
    Set cmd = New ADODB.Command
    cmd.ActiveConnection = conn
    cmd.commandText = cmdText

    For i = LBound(params) To UBound(params)
        cmd.Parameters.Append cmd.CreateParameter("@param" & i + 1, adVarChar, adParamInput, 255, params(i))
    Next i

    cmd.Execute
    Exit Sub

ErrorHandler:
    MsgBox "Error: " & Err.Description, vbCritical
    Exit Sub
End Sub






