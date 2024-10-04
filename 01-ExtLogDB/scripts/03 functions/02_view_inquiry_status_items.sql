-- version 0.6


CREATE OR REPLACE FUNCTION view_inquiry_status_items()
RETURNS TABLE (
    order_line_item_id INT,
    fulfillment_item_id INT,
    inquiry_status BOOLEAN,
    updated_by VARCHAR,
    updated_at TIMESTAMPTZ,
    role_id INT,
    user_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        order_line_item_id,
        fulfillment_item_id,
        inquiry_status,
        updated_by,
        updated_at,
        role_id,
        user_id
    FROM line_item_inquiry
    WHERE inquiry_status = TRUE;
END;
$$ LANGUAGE plpgsql;

