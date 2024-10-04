
-- version 0.7.6.1



CREATE OR REPLACE FUNCTION user_logout(
    p_session_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
BEGIN
    -- Get user information from the session
    SELECT user_id, role_id INTO v_user_id, v_role_id
    FROM user_sessions
    WHERE session_id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired session';
    END IF;

    -- Log the logout activity
    PERFORM log_user_activity(v_user_id, NULL, CURRENT_TIMESTAMP, 'User logged out');

    -- Invalidate the session
    PERFORM invalidate_session(p_session_id);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

