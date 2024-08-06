
-- validate session and permission (version checking new function permissions table)
-- version 0.7.14.23

CREATE OR REPLACE FUNCTION validate_session_and_permission(
    p_session_id UUID,
    p_function_name TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_id INT,
    role_id INT
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
        CASE WHEN us.user_id IS NOT NULL AND 
                  us.role_id <= fp.min_role_id
             THEN TRUE 
             ELSE FALSE 
        END as is_valid,
        us.user_id,
        us.role_id
    FROM validate_session(p_session_id) us
    CROSS JOIN function_perm fp;  -- This now correctly refers to the CTE named 'function_perm'
END;
$$ LANGUAGE plpgsql;




