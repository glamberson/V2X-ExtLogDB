
-- version 0.7.14.39

CREATE OR REPLACE FUNCTION set_user_role(p_db_role_name VARCHAR)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_db_role_name IS NOT NULL THEN
        EXECUTE 'SET ROLE ' || quote_ident(p_db_role_name);
    END IF;
END;
$$;

