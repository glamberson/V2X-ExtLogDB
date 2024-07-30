' global variables
' version 0.7.14

Option Explicit

' Declare a global variable to store the session token
Public g_sessionToken As String
Public g_conn As ADODB.Connection
Public g_connString As String

g_connString =              "Driver={PostgreSQL Unicode};" & _
                            "Server=localhost;" & _
                            "Port=5432;" & _
                            "Database=Beta_003;" & _
                            "Uid=login;" & _
                            "Pwd=FOTS-Egypt;"
    
