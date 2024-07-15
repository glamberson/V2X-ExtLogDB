-- version 0.6

-- archive line item


CREATE OR REPLACE FUNCTION archive_line_item(
    p_order_line_item_id INT,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Insert the line item into the archive table
    INSERT INTO archived_MRL_line_items (
        order_line_item_id,
        jcn,
        twcode,
        nomenclature,
        cog,
        fsc,
        niin,
        part_no,
        qty,
        ui,
        market_research_up,
        market_research_ep,
        availability_identifier,
        request_date,
        rdd,
        pri,
        swlin,
        hull_or_shop,
        suggested_source,
        mfg_cage,
        apl,
        nha_equipment_system,
        nha_model,
        nha_serial,
        techmanual,
        dwg_pc,
        requestor_remarks,
        inquiry_status,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        received_quantity,
        has_comments,
        multiple_fulfillments,
        archived_by,
        archived_at,
        archive_reason
    )
    SELECT
        order_line_item_id,
        jcn,
        twcode,
        nomenclature,
        cog,
        fsc,
        niin,
        part_no,
        qty,
        ui,
        market_research_up,
        market_research_ep,
        availability_identifier,
        request_date,
        rdd,
        pri,
        swlin,
        hull_or_shop,
        suggested_source,
        mfg_cage,
        apl,
        nha_equipment_system,
        nha_model,
        nha_serial,
        techmanual,
        dwg_pc,
        requestor_remarks,
        inquiry_status,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        received_quantity,
        has_comments,
        multiple_fulfillments,
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason
    FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;

    -- Delete the line item from the original table
    DELETE FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;

    -- Insert into audit trail
    INSERT INTO audit_trail (
        order_line_item_id,
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
        'Line Item Archived',
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Archive Operation',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;

