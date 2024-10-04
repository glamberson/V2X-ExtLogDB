-- version 0.7.4


-- process bulk update (fulfillment)


CREATE OR REPLACE FUNCTION process_bulk_update()
RETURNS VOID AS $$
BEGIN
    -- Update fulfillment items based on temp_bulk_update data
    UPDATE fulfillment_items fi
    SET 
        fi.shipdoc_tcn = tbu.shipdoc_tcn,
        fi.v2x_ship_no = tbu.v2x_ship_no,
        fi.booking = tbu.booking,
        fi.vessel = tbu.vessel,
        fi.container = tbu.container,
        fi.carrier = tbu.carrier,
        fi.sail_date = tbu.sail_date,
        fi.edd_to_ches = tbu.edd_to_ches,
        fi.rcd_v2x_date = tbu.rcd_v2x_date,
        fi.lot_id = tbu.lot_id,
        fi.triwall = tbu.triwall,
        fi.lsc_on_hand_date = tbu.lsc_on_hand_date,
        fi.arr_lsc_egypt = tbu.arr_lsc_egypt,
        fi.milstrip_req_no = tbu.milstrip_req_no,
        fi.updated_at = NOW(),
        fi.updated_by = 'bulk_update',
        fi.update_source = tbu.update_source,
        fi.comments = tbu.comments
    FROM temp_bulk_update tbu
    WHERE 
        tbu.order_line_item_id = fi.order_line_item_id 
        AND tbu.fulfillment_item_id = fi.fulfillment_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        details, 
        update_source, 
        changed_at
    )
    SELECT 
        tbu.order_line_item_id, 
        tbu.fulfillment_item_id, 
        'Bulk Update', 
        'admin_user', 
        tbu.reason, 
        tbu.update_source, 
        NOW()
    FROM temp_bulk_update tbu;

    -- Flag records with multiple fulfillment items
    UPDATE temp_bulk_update tbu
    SET flag_for_review = TRUE
    WHERE (
        SELECT COUNT(*) 
        FROM fulfillment_items fi 
        WHERE fi.order_line_item_id = tbu.order_line_item_id
    ) > 1;
END;
$$ LANGUAGE plpgsql;

