-- version 0.6

-- Create failed logins table


CREATE TABLE failed_logins (
    failed_login_id SERIAL PRIMARY KEY, -- Unique identifier for the failed login attempt
    username VARCHAR(100), -- Username of the person who attempted to log in
    attempt_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp of the failed login attempt
    reason TEXT -- Reason for the failed login attempt
);
