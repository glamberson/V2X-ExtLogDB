-- renew_session function
-- version 0.8.08

CREATE OR REPLACE FUNCTION renew_session(
    p_session_id UUID,
    p_duration INTERVAL
)
RETURNS VOID AS $$
BEGIN
    RAISE LOG 'Attempting to renew session: session_id = %, duration = %', p_session_id, p_duration;

    UPDATE user_sessions
    SET expires_at = NOW() + p_duration
    WHERE session_id = p_session_id
    AND expires_at > NOW(); -- Ensure we only renew active sessions

    IF FOUND THEN
        RAISE LOG 'Session renewed successfully: session_id %, new expires_at %', p_session_id, NOW() + p_duration;
    ELSE
        RAISE LOG 'Session not renewed: session_id %, duration %, expired or not found.', p_session_id, p_duration;
    END IF;
END;
$$ LANGUAGE plpgsql;
