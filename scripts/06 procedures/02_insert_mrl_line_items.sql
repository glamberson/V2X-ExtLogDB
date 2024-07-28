-- version 0.7.11

-- Procedure to insert MRL line items from JSONB data with update_source parameter


CREATE OR REPLACE PROCEDURE insert_mrl_line_items(batch_data jsonb, update_source text)
LANGUAGE plpgsql
AS $$
DECLARE
    item jsonb;
BEGIN
    FOR item IN
        SELECT * FROM jsonb_array_elements(batch_data)
    LOOP
        INSERT INTO MRL_line_items (
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
            update_source
        )
        VALUES (
            item->>'jcn',
            item->>'twcode',
            item->>'nomenclature',
            item->>'cog',
            item->>'fsc',
            item->>'niin',
            item->>'part_no',
            (item->>'qty')::int,
            item->>'ui',
            (item->>'market_research_up')::numeric,
            (item->>'market_research_ep')::numeric,
            item->>'availability_identifier',
            (item->>'request_date')::date,
            (item->>'rdd')::date,
            item->>'pri',
            item->>'swlin',
            item->>'hull_or_shop',
            item->>'suggested_source',
            item->>'mfg_cage',
            item->>'apl',
            item->>'nha_equipment_system',
            item->>'nha_model',
            item->>'nha_serial',
            item->>'techmanual',
            item->>'dwg_pc',
            item->>'requestor_remarks',
            (item->>'inquiry_status')::boolean,
            (item->>'created_by')::int,
            update_source
        );
        
        -- Log the action in the audit trail
        PERFORM log_audit(
            'INSERT',
            currval(pg_get_serial_sequence('MRL_line_items', 'order_line_item_id')),
            NULL,
            (item->>'created_by')::int,
            'New MRL line item created.',
            update_source
        );
    END LOOP;
END;
$$;

