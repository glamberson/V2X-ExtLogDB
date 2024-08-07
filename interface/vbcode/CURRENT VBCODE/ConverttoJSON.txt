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
