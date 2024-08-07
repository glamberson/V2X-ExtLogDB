
-- validate session and permission (version checking new function permissions table)

-- version 0.7.14.29

CREATE OR REPLACE FUNCTION validate_session_and_permission(
    p_session_id UUID,
    p_function_name TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    session_user_id INT,
    session_role_id INT
) AS $$
BEGIN
    RETURN QUERY
    WITH function_perm AS (
        SELECT min_role_id
        FROM function_permissions
        WHERE function_name = p_function_name
        UNION ALL
        SELECT 9  -- Default to role 9 if function not found in table
        LIMIT 1
    )
    SELECT 
        CASE WHEN vs.session_user_id IS NOT NULL AND 
                  vs.session_role_id <= fp.min_role_id
             THEN TRUE 
             ELSE FALSE 
        END as is_valid,
        vs.session_user_id,
        vs.session_role_id
    FROM validate_session(p_session_id) vs
    CROSS JOIN function_perm fp;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

