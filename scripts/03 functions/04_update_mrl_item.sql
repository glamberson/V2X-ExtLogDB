-- version 0.7.4



CREATE OR REPLACE FUNCTION update_mrl_line_item(
    p_order_line_item_id INT,
    p_field_name VARCHAR,
    p_new_value TEXT,
    p_updated_by VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Construct dynamic SQL to update the specified field
    EXECUTE 'UPDATE MRL_line_items SET ' || p_field_name || ' = $1 WHERE order_line_item_id = $2'
    USING p_new_value, p_order_line_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        p_order_line_item_id,
        'Update',
        p_updated_by,
        'Updated ' || p_field_name || ' to ' || p_new_value,
        p_role_id,
        (SELECT user_id FROM users WHERE username = p_updated_by)
    );
END;
$$ LANGUAGE plpgsql;

