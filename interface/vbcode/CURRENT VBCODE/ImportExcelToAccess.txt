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