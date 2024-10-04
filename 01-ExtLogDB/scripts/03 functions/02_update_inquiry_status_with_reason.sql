-- version 0.6


-- function to update inquiry status with reason (added fields, cleaned up)


CREATE OR REPLACE FUNCTION update_inquiry_status_with_reason(
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_inquiry_status BOOLEAN,
    p_updated_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    UPDATE line_item_inquiry
    SET inquiry_status = p_inquiry_status,
        updated_by = p_updated_by,
        updated_at = CURRENT_TIMESTAMP,
        role_id = p_role_id,
        user_id = p_user_id
    WHERE order_line_item_id = p_order_line_item_id
    AND fulfillment_item_id = p_fulfillment_item_id;

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
        'Inquiry Status Updated',
        p_updated_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Inquiry Update',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;

