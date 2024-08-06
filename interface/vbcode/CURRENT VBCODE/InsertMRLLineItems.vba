
' insert mrl line items
' version 0.7.14.24

Public Sub InsertMRLLineItems()
    Dim jsonData As String
    Dim updateSource As String
    Dim result As Variant
    
    Set frm = Forms!frMRL
    jsonData = ConvertToJSON()
    updateSource = frm.txtUpdateSource.Value ' Get the update source from the text box
    
    ' Debugging output
    MsgBox jsonData
    
    ' Call the protected function
    result = ExecuteProtectedFunction("insert_mrl_line_items", jsonData, updateSource)
    
    ' Check the result if needed
    If Not IsNull(result) Then
        MsgBox "Data inserted successfully", vbInformation
    Else
        MsgBox "Failed to insert data", vbExclamation
    End If
End Sub

