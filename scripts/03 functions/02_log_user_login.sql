-- version 0/6


CREATE OR REPLACE FUNCTION log_user_login()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_activity (
        user_id,
        login_time,
        activity_details
    )
    VALUES (
        NEW.user_id,
        CURRENT_TIMESTAMP,
        'User logged in'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
