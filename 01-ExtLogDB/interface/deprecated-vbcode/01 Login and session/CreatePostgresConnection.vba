' CreatePostgresConnection
' version 0.7.6.1
Public Function CreatePostgresConnection() As ADODB.Connection
    Dim conn As ADODB.Connection
    Set conn = New ADODB.Connection

    conn.ConnectionString = "Driver={PostgreSQL Unicode};" & _
                            "Server=localhost;" & _
                            "Port=5432;" & _
                            "Database=Beta_003;" & _
                            "Uid=login;" & _
                            "Pwd=FOTS-Egypt;"
    conn.Open
    
    Set CreatePostgresConnection = conn
End Function