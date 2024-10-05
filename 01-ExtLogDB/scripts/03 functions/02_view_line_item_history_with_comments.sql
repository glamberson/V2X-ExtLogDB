-- version 0.6

-- view line item history with comments


CREATE OR REPLACE FUNCTION view_line_item_history_with_comments(
    p_order_line_item_id INT
)
RETURNS TABLE (
    audit_id INT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    action VARCHAR,
    changed_by VARCHAR,
    changed_at TIMESTAMPTZ,
    details TEXT,
    update_source TEXT,
    role_id INT,
    user_id INT,
    comment_id INT,
    comment TEXT,
    commented_by VARCHAR,
    commented_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.audit_id,
        a.order_line_item_id,
        a.fulfillment_item_id,
        a.action,
        a.changed_by,
        a.changed_at,
        a.details,
        a.update_source,
        a.role_id,
        a.user_id,
        c.comment_id,
        c.comment,
        c.commented_by,
        c.commented_at
    FROM 
        audit_trail a
    LEFT JOIN 
        line_item_comments c
    ON 
        a.order_line_item_id = c.order_line_item_id
    WHERE 
        a.order_line_item_id = p_order_line_item_id;
END;
$$ LANGUAGE plpgsql;

