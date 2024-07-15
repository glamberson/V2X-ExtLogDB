-- version 0.6


CREATE OR REPLACE FUNCTION log_failed_login_attempt(
    p_username VARCHAR,
    p_reason TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO failed_logins (
        username,
        attempt_time,
        reason
    )
    VALUES (
        p_username,
        CURRENT_TIMESTAMP,
        p_reason
    );
END;
$$ LANGUAGE plpgsql;
