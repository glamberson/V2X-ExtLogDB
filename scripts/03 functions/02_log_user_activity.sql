-- version 0.6


CREATE OR REPLACE FUNCTION log_user_activity(
    p_user_id INT,
    p_login_time TIMESTAMPTZ,
    p_logout_time TIMESTAMPTZ,
    p_activity_details TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO user_activity (
        user_id,
        login_time,
        logout_time,
        activity_details
    )
    VALUES (
        p_user_id,
        p_login_time,
        p_logout_time,
        p_activity_details
    );
END;
$$ LANGUAGE plpgsql;


