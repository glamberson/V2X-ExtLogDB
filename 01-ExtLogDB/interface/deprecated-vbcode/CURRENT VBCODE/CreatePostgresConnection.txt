' CreatePostgresConnection
' version 0.7.14.4


Public Function CreatePostgresConnection() As ADODB.Connection
    ' Just return the existing connection as it's supposed to be initialized only once
    Set CreatePostgresConnection = g_conn
End Function
