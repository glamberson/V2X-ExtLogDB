-- version 0.7.14.29

CREATE OR REPLACE FUNCTION validate_session(p_session_id UUID)
RETURNS TABLE (
    session_user_id INT,
    session_role_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT user_id AS session_user_id, role_id AS session_role_id
    FROM user_sessions
    WHERE session_id = p_session_id AND expires_at > CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

