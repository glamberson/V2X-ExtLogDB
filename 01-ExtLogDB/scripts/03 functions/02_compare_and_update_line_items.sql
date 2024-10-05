-- version 0.6

-- compare and update line items function


CREATE OR REPLACE FUNCTION compare_and_update_line_items(
    p_temp_table_name TEXT
)
RETURNS VOID AS $$
DECLARE
    r RECORD;
    v_status_id INT;
BEGIN
    FOR r IN EXECUTE 'SELECT * FROM ' || p_temp_table_name LOOP
        -- Check if the order_line_item_id exists in MRL_line_items
        IF EXISTS (SELECT 1 FROM MRL_line_items WHERE order_line_item_id = r.order_line_item_id) THEN
            -- Update existing line item
            UPDATE MRL_line_items
            SET jcn = r.jcn,
                twcode = r.twcode,
                nomenclature = r.nomenclature,
                cog = r.cog,
                fsc = r.fsc,
                niin = r.niin,
                part_no = r.part_no,
                qty = r.qty,
                ui = r.ui,
                market_research_up = r.market_research_up,
                market_research_ep = r.market_research_ep,
                availability_identifier = r.availability_identifier,
                request_date = r.request_date,
                rdd = r.rdd,
                pri = r.pri,
                swlin = r.swlin,
                hull_or_shop = r.hull_or_shop,
                suggested_source = r.suggested_source,
                mfg_cage = r.mfg_cage,
                apl = r.apl,
                nha_equipment_system = r.nha_equipment_system,
                nha_model = r.nha_model,
                nha_serial = r.nha_serial,
                techmanual = r.techmanual,
                dwg_pc = r.dwg_pc,
                requestor_remarks = r.requestor_remarks,
                inquiry_status = r.inquiry_status,
                updated_by = r.updated_by,
                updated_at = CURRENT_TIMESTAMP,
                update_source = r.update_source
            WHERE order_line_item_id = r.order_line_item_id;

            -- Update fulfillment status
            v_status_id := (SELECT status_id FROM statuses WHERE status_name = r.status_name);
            PERFORM update_fulfillment_status(
                r.order_line_item_id,
                r.fulfillment_item_id,
                v_status_id,
                r.updated_by,
                r.update_source,
                r.role_id,
                r.user_id
            );
        ELSE
            -- Insert new line item
            INSERT INTO MRL_line_items (
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
                update_source
            ) VALUES (
                r.order_line_item_id,
                r.jcn,
                r.twcode,
                r.nomenclature,
                r.cog,
                r.fsc,
                r.niin,
                r.part_no,
                r.qty,
                r.ui,
                r.market_research_up,
                r.market_research_ep,
                r.availability_identifier,
                r.request_date,
                r.rdd,
                r.pri,
                r.swlin,
                r.hull_or_shop,
                r.suggested_source,
                r.mfg_cage,
                r.apl,
                r.nha_equipment_system,
                r.nha_model,
                r.nha_serial,
                r.techmanual,
                r.dwg_pc,
                r.requestor_remarks,
                r.inquiry_status,
                r.created_by,
                CURRENT_TIMESTAMP,
                r.updated_by,
                CURRENT_TIMESTAMP,
                r.update_source
            );

            -- Insert initial fulfillment item
            INSERT INTO fulfillment_items (
                order_line_item_id,
                created_by,
                status_id
            ) VALUES (
                r.order_line_item_id,
                r.created_by,
                (SELECT status_id FROM statuses WHERE status_name = r.status_name)
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

