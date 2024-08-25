-- renew_session function
-- version 0.8.23

CREATE OR REPLACE FUNCTION renew_session(
    p_session_id UUID,
    p_duration INTERVAL
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_updated INT;
BEGIN
    RAISE LOG 'Attempting to renew session: session_id = %, duration = %', p_session_id, p_duration;

    UPDATE user_sessions
    SET expires_at = NOW() + p_duration
    WHERE session_id = p_session_id
    AND expires_at > NOW(); -- Ensure we only renew active sessions

    GET DIAGNOSTICS rows_updated = ROW_COUNT;

    IF rows_updated > 0 THEN
        RAISE LOG 'Session renewed successfully: session_id %, new expires_at %', p_session_id, NOW() + p_duration;
        RETURN TRUE;
    ELSE
        RAISE LOG 'Session not renewed: session_id %, duration %, expired or not found.', p_session_id, p_duration;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

