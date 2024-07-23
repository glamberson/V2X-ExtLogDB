-- version 0.7.2

-- SESSION Functions
-- functions included: create_session, validate_session, invalidate_session


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

-- Function to validate a session
CREATE OR REPLACE FUNCTION validate_session(p_session_id UUID)
RETURNS TABLE (user_id INT, role_id INT) AS $$
BEGIN
    RETURN QUERY
    SELECT user_id, role_id
    FROM user_sessions
    WHERE session_id = p_session_id
    AND expires_at > CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to invalidate a session
CREATE OR REPLACE FUNCTION invalidate_session(p_session_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_sessions
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;
