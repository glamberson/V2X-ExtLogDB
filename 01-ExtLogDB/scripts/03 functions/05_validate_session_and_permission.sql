-- validate session and permission (version checking new function permissions table)

-- version 0.8.07

CREATE OR REPLACE FUNCTION validate_session_and_permission(
    p_session_id UUID,
    p_function_name TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    session_user_id INT,
    session_role_id INT
) AS $$
DECLARE
    vs RECORD;
    fp RECORD;
BEGIN
    -- Get the minimum role_id required for the function
    SELECT INTO fp min_role_id
    FROM function_permissions
    WHERE function_name = p_function_name
    UNION ALL
    SELECT 9  -- Default to role 9 if function not found in table
    LIMIT 1;

    -- Validate the session
    SELECT INTO vs *
    FROM validate_session(p_session_id);

    -- Determine if the session is valid and has sufficient permissions
    is_valid := vs.session_user_id IS NOT NULL AND vs.session_role_id <= fp.min_role_id;
    session_user_id := vs.session_user_id;
    session_role_id := vs.session_role_id;

    -- Renew the session if valid
    IF is_valid THEN
        BEGIN
            PERFORM renew_session(p_session_id, '1 hour');
        EXCEPTION WHEN OTHERS THEN
            RAISE LOG 'Error renewing session: %', SQLERRM;
        END;
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
