-- version 0.7.14.10 enhanced debug

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
    v_jcn TEXT;
    v_twcode TEXT;
    v_qty INT;
    v_market_research_up NUMERIC;
    v_market_research_ep NUMERIC;
    v_request_date DATE;
    v_rdd DATE;
    v_inquiry_status BOOLEAN;
BEGIN
    -- Initial debug logging
    RAISE NOTICE 'insert_mrl_line_items started. Parameters: batch_data=%, update_source=%', batch_data, update_source;

    -- Retrieve and log session variables
    BEGIN
        user_id := current_setting('myapp.user_id')::INT;
        role_id := current_setting('myapp.role_id')::INT;
        RAISE NOTICE 'Session variables: user_id=%, role_id=%', user_id, role_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error retrieving session variables: %, SQLSTATE: %', SQLERRM, SQLSTATE;
    END;

    -- Loop through each item in the JSONB array
    FOR item IN SELECT * FROM jsonb_array_elements(batch_data)
    LOOP
        RAISE NOTICE 'Processing item: %', item;

        BEGIN
            -- Extract and validate key fields
            v_jcn := item->>'jcn';
            v_twcode := item->>'twcode';
            v_qty := (item->>'qty')::INT;
            v_market_research_up := (item->>'market_research_up')::NUMERIC;
            v_market_research_ep := (item->>'market_research_ep')::NUMERIC;
            v_request_date := (item->>'request_date')::DATE;
            v_rdd := (item->>'rdd')::DATE;
            v_inquiry_status := (item->>'inquiry_status')::BOOLEAN;

            RAISE NOTICE 'Extracted values: jcn=%, twcode=%, qty=%, market_research_up=%, market_research_ep=%, request_date=%, rdd=%, inquiry_status=%',
                         v_jcn, v_twcode, v_qty, v_market_research_up, v_market_research_ep, v_request_date, v_rdd, v_inquiry_status;

            -- Insert into MRL_line_items table
            INSERT INTO MRL_line_items (
                jcn, twcode, nomenclature, cog, fsc, niin, part_no, qty, ui,
                market_research_up, market_research_ep, availability_identifier,
                request_date, rdd, pri, swlin, hull_or_shop, suggested_source,
                mfg_cage, apl, nha_equipment_system, nha_model, nha_serial,
                techmanual, dwg_pc, requestor_remarks, inquiry_status,
                created_by, update_source
            ) VALUES (
                v_jcn, v_twcode, item->>'nomenclature', item->>'cog', item->>'fsc',
                item->>'niin', item->>'part_no', v_qty, item->>'ui',
                v_market_research_up, v_market_research_ep, item->>'availability_identifier',
                v_request_date, v_rdd, item->>'pri', item->>'swlin', item->>'hull_or_shop',
                item->>'suggested_source', item->>'mfg_cage', item->>'apl',
                item->>'nha_equipment_system', item->>'nha_model', item->>'nha_serial',
                item->>'techmanual', item->>'dwg_pc', item->>'requestor_remarks',
                v_inquiry_status, user_id, update_source
            ) RETURNING order_line_item_id INTO new_order_line_item_id;

            RAISE NOTICE 'Inserted new MRL line item with ID: %', new_order_line_item_id;

            -- Call the log_audit function
            BEGIN
                PERFORM log_audit(
                    'INSERT'::TEXT, 
                    new_order_line_item_id,
                    NULL::INT,
                    'Inserted new MRL line item'::TEXT,
                    update_source
                );
                RAISE NOTICE 'log_audit called successfully for order_line_item_id: %', new_order_line_item_id;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error in log_audit: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                RAISE NOTICE 'Problematic data: new_order_line_item_id=%, update_source=%',
                             new_order_line_item_id, update_source;
            END;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error inserting MRL line item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
            RAISE NOTICE 'Problematic item: %', item;
        END;
    END LOOP;

    RAISE NOTICE 'insert_mrl_line_items completed successfully.';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Unhandled exception in insert_mrl_line_items: %, SQLSTATE: %', SQLERRM, SQLSTATE;
END;
$$;


