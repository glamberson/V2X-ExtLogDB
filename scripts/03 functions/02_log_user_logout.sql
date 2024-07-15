-- version 0.6

CREATE OR REPLACE FUNCTION log_user_logout()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE user_activity
    SET logout_time = CURRENT_TIMESTAMP,
        activity_details = activity_details || '; User logged out'
    WHERE user_id = NEW.user_id
    AND logout_time IS NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

