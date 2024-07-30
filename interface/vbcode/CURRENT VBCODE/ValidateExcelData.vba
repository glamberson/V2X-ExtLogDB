
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
        
 

