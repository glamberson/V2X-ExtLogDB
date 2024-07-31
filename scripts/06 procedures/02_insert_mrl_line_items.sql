-- version 0.7.14.6

-- Procedure to insert MRL line items from JSONB data with update_source parameter


CREATE OR REPLACE PROCEDURE insert_mrl_line_items(
    batch_data jsonb,
    update_source TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    item jsonb;
    user_id INT;
    role_id INT;
    new_order_line_item_id INT;
BEGIN
    -- Get user_id and role_id from the session settings and cast them to INT
    user_id := current_setting('myapp.user_id')::INT;
    role_id := current_setting('myapp.role_id')::INT;

    -- Loop through each item in the JSONB array
    FOR item IN
        SELECT * FROM jsonb_array_elements(batch_data)
    LOOP
        -- Insert into MRL_line_items table
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
        ) VALUES (
            item->>'jcn',
            item->>'twcode',
            item->>'nomenclature',
            item->>'cog',
            item->>'fsc',
            item->>'niin',
            item->>'part_no',
            (item->>'qty')::INT,
            item->>'ui',
            (item->>'market_research_up')::NUMERIC,
            (item->>'market_research_ep')::NUMERIC,
            item->>'availability_identifier',
            (item->>'request_date')::DATE,
            (item->>'rdd')::DATE,
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
            (item->>'inquiry_status')::BOOLEAN,
            user_id,
            update_source
        ) RETURNING order_line_item_id INTO new_order_line_item_id;

        -- Call the log_audit function with explicitly cast parameters
        PERFORM log_audit(
            'INSERT', 
            new_order_line_item_id::INT, 
            NULL::INT, 
            'Bulk Insert MRL Line Item Process',
            update_source::TEXT
        );
    END LOOP;
END;
$$;

