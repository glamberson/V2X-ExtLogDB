' CreatePostgresConnection
' version 0.7.14


Public Function CreatePostgresConnection() As ADODB.Connection
    If g_conn Is Nothing Then
        Set g_conn = New ADODB.Connection
        g_conn.ConnectionString = g_connString
        g_conn.Open
    ElseIf g_conn.State = adStateClosed Then
        g_conn.Open
    End If
    Set CreatePostgresConnection = g_conn
End Function


