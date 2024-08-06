-- version 0.7.14.28

-- Function to create a session
CREATE OR REPLACE FUNCTION create_session(p_user_id INT, p_role_id INT, p_duration INTERVAL)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
BEGIN
    INSERT INTO user_sessions (user_id, role_id, expires_at)
    VALUES (p_user_id, p_role_id, CURRENT_TIMESTAMP + p_duration)
    RETURNING session_id INTO v_session_id;

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

