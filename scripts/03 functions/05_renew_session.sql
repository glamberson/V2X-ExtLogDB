-- version 0.7.14.20

CREATE OR REPLACE FUNCTION renew_session(p_session_id UUID, p_duration INTERVAL)
RETURNS BOOLEAN AS $$
DECLARE
    v_expires_at TIMESTAMPTZ;
BEGIN
    UPDATE user_sessions
    SET expires_at = CURRENT_TIMESTAMP + p_duration
    WHERE session_id = p_session_id
    AND expires_at > CURRENT_TIMESTAMP
    RETURNING expires_at INTO v_expires_at;
    
    RETURN v_expires_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql;