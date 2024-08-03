-- version 0.7.14.21

CREATE OR REPLACE FUNCTION validate_session_and_permission(
    p_session_id UUID,
    p_required_role_id INT
) RETURNS TABLE (
    is_valid BOOLEAN,
    user_id INT,
    role_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE WHEN us.user_id IS NOT NULL AND 
                  (r.role_id = p_required_role_id OR p_required_role_id = 0)
             THEN TRUE 
             ELSE FALSE 
        END as is_valid,
        us.user_id,
        us.role_id
    FROM validate_session(p_session_id) us
    LEFT JOIN roles r ON us.role_id = r.role_id;
END;
$$ LANGUAGE plpgsql;


