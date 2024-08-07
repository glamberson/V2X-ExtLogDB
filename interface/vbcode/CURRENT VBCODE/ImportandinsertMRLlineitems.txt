' import and insert mrl line items
' version 0.7.12
Sub ImportAndInsertMRLLineItems()
    If Not ValidateExcelData() Then
        MsgBox "Data validation failed. Please correct the errors and try again."
        Exit Sub
    End If
    
    ImportExcelToAccess
    InsertMRLLineItems
End Sub


