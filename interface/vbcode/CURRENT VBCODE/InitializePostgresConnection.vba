' Initialize Postgres Connection
' version 0.7.14.4

Public Sub InitializePostgresConnection()
    If g_conn Is Nothing Then
        g_connString = "Driver={PostgreSQL Unicode};" & _
                       "Server=localhost;" & _
                       "Port=5432;" & _
                       "Database=Beta_003;" & _
                       "Uid=login;" & _
                       "Pwd=FOTS-Egypt;"
        Set g_conn = New ADODB.Connection
        g_conn.ConnectionString = g_connString
        g_conn.Open
    End If
End Sub
