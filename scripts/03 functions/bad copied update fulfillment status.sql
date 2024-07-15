-- 0.6

-- bad copied update fulfillment function


CREATE OR REPLACE FUNCTION update_fulfillment_status(
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_status_id INT,
    p_updated_by VARCHAR,
    p_update_source TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    UPDATE fulfillment_items
    SET status_id = p_status_id,
        updated_by = p_updated_by,
        updated_at = CURRENT_TIMESTAMP,
        update_source = p_update_source
    WHERE fulfillment_item_id = p_fulfillment_item_id;

    INSERT INTO audit_trail (
        order_line_item_id,
        fulfillment_item_id,
        action,
        changed_by,
        changed_at,
        details,
        update_source,
        role_id,
        user_id
    )
    VALUES (
        p_order_line_item_id,
        p_fulfillment_item_id,
        'Fulfillment Status Updated',
        p_updated_by,
        CURRENT_TIMESTAMP,
        'Status ID: ' || p_status_id,
        p_update_source,
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;

