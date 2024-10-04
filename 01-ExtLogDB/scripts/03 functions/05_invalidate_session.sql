-- version 0.7.14.28

-- Function to invalidate a session
CREATE OR REPLACE FUNCTION invalidate_session(p_session_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_sessions
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;
