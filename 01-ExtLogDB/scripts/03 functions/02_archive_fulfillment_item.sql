-- version 0.6

-- archive fulfillment item


CREATE OR REPLACE FUNCTION archive_fulfillment_item(
    p_fulfillment_item_id INT,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Insert the fulfillment item into the archive table
    INSERT INTO archived_fulfillment_items (
        fulfillment_item_id,
        order_line_item_id,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        shipdoc_tcn,
        v2x_ship_no,
        booking,
        vessel,
        container,
        sail_date,
        edd_to_ches,
        rcd_v2x_date,
        lot_id,
        triwall,
        lsc_on_hand_date,
        arr_lsc_egypt,
        milstrip_req_no,
        inquiry_status,
        comments,
        archived_by,
        archived_at,
        archive_reason
    )
    SELECT
        fulfillment_item_id,
        order_line_item_id,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        shipdoc_tcn,
        v2x_ship_no,
        booking,
        vessel,
        container,
        sail_date,
        edd_to_ches,
        rcd_v2x_date,
        lot_id,
        triwall,
        lsc_on_hand_date,
        arr_lsc_egypt,
        milstrip_req_no,
        inquiry_status,
        comments,
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason
    FROM fulfillment_items
    WHERE fulfillment_item_id = p_fulfillment_item_id;

    -- Delete the fulfillment item from the original table
    DELETE FROM fulfillment_items
    WHERE fulfillment_item_id = p_fulfillment_item_id;

    -- Insert into audit trail
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
        (SELECT order_line_item_id FROM fulfillment_items WHERE fulfillment_item_id = p_fulfillment_item_id),
        p_fulfillment_item_id,
        'Fulfillment Item Archived',
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Archive Operation',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;


