-- version 0.6.3

-- log audit

CREATE OR REPLACE FUNCTION log_audit(action TEXT, order_line_item_id INT, fulfillment_item_id INT, changed_by INT, details TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_trail (
        order_line_item_id, fulfillment_item_id, action, changed_by, changed_at, details, update_source, role_id, user_id
    ) VALUES (
        order_line_item_id, fulfillment_item_id, action, changed_by, CURRENT_TIMESTAMP, details, current_setting('update_source'), current_setting('role.id'), current_setting('user.id')
    );
END;
$$ LANGUAGE plpgsql;
