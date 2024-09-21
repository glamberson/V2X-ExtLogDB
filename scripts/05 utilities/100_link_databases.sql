


CREATE SERVER reportsdb_server
FOREIGN DATA WRAPPER dblink_fdw
OPTIONS (host 'localhost', dbname 'ReportsDB');


CREATE USER MAPPING FOR CURRENT_USER
SERVER reportsdb_server
OPTIONS (user 'postgres', password '123456');


