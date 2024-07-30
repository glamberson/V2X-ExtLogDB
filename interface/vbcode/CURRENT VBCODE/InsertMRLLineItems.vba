
' insert mrl line items
' version 0.7.12
Public Sub InsertMRLLineItems()
    Dim conn As ADODB.Connection
    Dim cmd As ADODB.Command
    Dim jsonData As String
    Dim param As ADODB.Parameter
    
    jsonData = ConvertToJSON()
    
    Set frm = Forms!frMRL
    updateSource = frm.txtUpdateSource.Value ' Get the update source from the text box
    ' Debugging output
    MsgBox jsonData
    
    Set conn = CreatePostgresConnection()
    Set cmd = New ADODB.Command
    
    With cmd
        .ActiveConnection = conn
        .CommandType = adCmdText
        .commandText = "CALL insert_mrl_line_items(?, ?)"
        .Parameters.Append .CreateParameter("@batch_data", adLongVarChar, adParamInput, Len(jsonData), jsonData)
        .Parameters.Append .CreateParameter("@update_source", adVarChar, adParamInput, Len(updateSource), updateSource)
        .Execute
    End With
    
    conn.Close
End Sub

