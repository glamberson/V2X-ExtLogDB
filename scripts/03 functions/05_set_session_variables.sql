-- version 0.7.14.17

CREATE OR REPLACE FUNCTION set_session_variables(p_session_id UUID, p_user_id INT, p_role_id INT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('myapp.session_id', p_session_id::TEXT, FALSE);
    PERFORM set_config('myapp.user_id', p_user_id::TEXT, FALSE);
    PERFORM set_config('myapp.role_id', p_role_id::TEXT, FALSE);
END;
$$ LANGUAGE plpgsql;

