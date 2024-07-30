

' 0.7.12
Sub ImportAndInsertMRLLineItems()
    If Not ValidateExcelData() Then
        MsgBox "Data validation failed. Please correct the errors and try again."
        Exit Sub
    End If
    
    ImportExcelToAccess
    InsertMRLLineItems
End Sub

' import excel to access
' version 0.7.12
Sub ImportExcelToAccess()
    Dim filePath As String
    Dim xlApp As Object
    Dim xlWorkbook As Object
    Dim xlSheet As Object
    Dim col As Integer
    
    filePath = "C:\Beta_003\MRL.xlsx"
    
    ' Create a new Excel application instance
    Set xlApp = CreateObject("Excel.Application")
    ' Open the workbook
    Set xlWorkbook = xlApp.Workbooks.Open(filePath)
    ' Set the worksheet
    Set xlSheet = xlWorkbook.Sheets("Sheet1") ' Adjust to your sheet name
    
    ' Clean up field names in the first row
    For col = 1 To xlSheet.UsedRange.Columns.Count
        xlSheet.Cells(1, col).Value = Trim(xlSheet.Cells(1, col).Value)
    Next col
    
    ' Save and close the workbook
    xlWorkbook.Save
    xlWorkbook.Close False
    ' Quit Excel application
    xlApp.Quit
    
    ' Clean up
    Set xlSheet = Nothing
    Set xlWorkbook = Nothing
    Set xlApp = Nothing

    ' Import the cleaned Excel file into Access
    DoCmd.TransferSpreadsheet acImport, acSpreadsheetTypeExcel12, "TempTable", filePath, True
End Sub

'Convert to JSON
'version 0.7.12
Public Function ConvertToJSON() As String
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim json As String
    Dim f As DAO.Field
    Dim keyFields As Collection
    Dim keyField As Variant
    Dim isEmptyRecord As Boolean
    Dim trimmedFieldName As String
    
    ' Define the key fields to check
    Set keyFields = New Collection
    keyFields.Add "jcn"
    keyFields.Add "twcode"
    keyFields.Add "qty"
    keyFields.Add "request_date"
    ' Add other key fields as needed

    Set db = CurrentDb()
    Set rs = db.OpenRecordset("SELECT * FROM TempTable")

    If rs.EOF Then
        ConvertToJSON = "[]"
        Exit Function
    End If

    ' Debug: Print all field names in the Recordset
    Debug.Print "Field names in TempTable:"
    For Each f In rs.Fields
        Debug.Print "[" & Trim(f.Name) & "]"
    Next f

    json = "["
    
    Do While Not rs.EOF
        isEmptyRecord = True
        
        ' Check if key fields are empty
        For Each keyField In keyFields
            On Error Resume Next
            ' Trim the field name to remove any leading/trailing spaces
            trimmedFieldName = Trim(keyField)
            If IsNull(rs.Fields(trimmedFieldName)) Or rs.Fields(trimmedFieldName).Value = "" Then
                Debug.Print "Field not found or empty: " & "[" & trimmedFieldName & "]"
            Else
                isEmptyRecord = False
                Exit For
            End If
            On Error GoTo 0
        Next keyField
        
        If Not isEmptyRecord Then
            json = json & "{"
            For Each f In rs.Fields
                trimmedFieldName = Trim(f.Name)
                json = json & """" & trimmedFieldName & """:"
                If IsNull(f.Value) Then
                    json = json & "null"
                ElseIf f.Type = dbText Then
                    json = json & """" & Replace(Replace(f.Value, "\", "\\"), """", "\""") & """"
                ElseIf f.Type = dbDate Then
                    json = json & """" & Format(f.Value, "yyyy-mm-ddThh:nn:ss") & """"
                Else
                    json = json & f.Value
                End If
                json = json & ","
            Next f
            json = Left(json, Len(json) - 1) ' Remove trailing comma
            json = json & "},"
        End If

        rs.MoveNext
    Loop
    
    If Right(json, 1) = "," Then
        json = Left(json, Len(json) - 1) ' Remove trailing comma from the last record
    End If
    
    json = json & "]"
    
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    
    ConvertToJSON = json
End Function

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

' validate excel data
' version 0.7.12
Public Function ValidateExcelData() As Boolean
    Dim xlApp As Object
    Dim xlWorkbook As Object
    Dim xlSheet As Object
    Dim row As Integer
    Dim isValid As Boolean
    
    ' Create a new Excel application instance
    Set xlApp = CreateObject("Excel.Application")
    ' Open the workbook
    Set xlWorkbook = xlApp.Workbooks.Open("C:\Beta_003\MRL.xlsx")
    ' Set the worksheet
    Set xlSheet = xlWorkbook.Sheets("Sheet1") ' Adjust to your sheet name
    isValid = True
    
    For row = 2 To xlSheet.Cells(xlSheet.Rows.Count, "A").End(-4162).row ' Assuming row 1 is the header row
        If IsEmpty(xlSheet.Cells(row, 1)) Then ' Validate jcn
            MsgBox "Error: jcn is required at row " & row
            isValid = False
        End If
        
        If Not IsNumeric(xlSheet.Cells(row, 8)) Or xlSheet.Cells(row, 8).Value <= 0 Then ' Validate qty
            MsgBox "Error: qty must be a positive number at row " & row
            isValid = False
        End If
        
        If Not IsDate(xlSheet.Cells(row, 13)) Then ' Validate request_date
            MsgBox "Error: request_date must be a valid date at row " & row
            isValid = False
        End If
        
        If Not IsNumeric(xlSheet.Cells(row, 28)) Then ' Validate created_by
            MsgBox "Error: created_by must be a number at row " & row
            isValid = False
        End If
        
        ' Additional validation rules can be added here...
        
        If Not isValid Then Exit For
    Next row
    
    ' Close the workbook without saving
    xlWorkbook.Close False
    ' Quit Excel application
    xlApp.Quit
    
    ' Clean up
    Set xlSheet = Nothing
    Set xlWorkbook = Nothing
    Set xlApp = Nothing
    
    ValidateExcelData = isValid
End Function
        
 

