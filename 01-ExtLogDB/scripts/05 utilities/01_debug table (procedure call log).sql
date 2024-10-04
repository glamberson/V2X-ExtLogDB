-- Create a table to log procedure invocations
CREATE TABLE procedure_call_log (
    id SERIAL PRIMARY KEY,
    procedure_name TEXT,
    call_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
