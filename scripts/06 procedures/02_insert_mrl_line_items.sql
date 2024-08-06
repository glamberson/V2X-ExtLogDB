-- version 0.7.14.27 4x changed session and userid roleid configuration and syntax fixed

-- Procedure to insert MRL line items from JSONB data with update_source parameter

CREATE OR REPLACE PROCEDURE insert_mrl_line_items(
    batch_data jsonb,
    update_source TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    item jsonb;
    current_user_id INT;
    current_role_id INT;
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
    RAISE LOG 'insert_mrl_line_items started';
    RAISE LOG 'Batch data: %', batch_data;
    RAISE LOG 'Update source: %', update_source;

    -- Retrieve and log session variables
    RAISE LOG 'Attempting to retrieve session variables';
    
    -- Get session variables
    current_user_id := current_setting('myapp.user_id', true)::INT;
    current_role_id := current_setting('myapp.role_id', true)::INT;

    -- Validate batch_data
    IF batch_data IS NULL OR jsonb_typeof(batch_data) != 'array' THEN
        RAISE LOG 'Invalid batch_data: not a JSON array or is NULL';
        RETURN;
    END IF;

    -- Loop through each item in the JSONB array
    RAISE LOG 'Starting to process batch items';
    FOR item IN SELECT * FROM jsonb_array_elements(batch_data)
    LOOP
        RAISE LOG 'Processing item: %', item;

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

            RAISE LOG 'Extracted values: jcn=%, twcode=%, qty=%, market_research_up=%, market_research_ep=%, request_date=%, rdd=%, inquiry_status=%',
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
                v_inquiry_status, current_user_id, update_source
            ) RETURNING order_line_item_id INTO new_order_line_item_id;

            RAISE LOG 'Inserted new MRL line item with ID: %', new_order_line_item_id;

            -- Call the log_audit function
            BEGIN
                PERFORM log_audit(
                    'INSERT'::TEXT, 
                    new_order_line_item_id,
                    NULL::INT,
                    'Inserted new MRL line item'::TEXT,
                    update_source
                );
                RAISE LOG 'log_audit called successfully for order_line_item_id: %', new_order_line_item_id;
            EXCEPTION WHEN OTHERS THEN
                RAISE LOG 'Error in log_audit: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                RAISE LOG 'Problematic data: new_order_line_item_id=%, update_source=%',
                             new_order_line_item_id, update_source;
            END;
        EXCEPTION WHEN OTHERS THEN
            RAISE LOG 'Error inserting MRL line item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
            RAISE LOG 'Problematic item: %', item;
        END;

        RAISE LOG 'Finished processing item';
    END LOOP;

    RAISE LOG 'insert_mrl_line_items completed successfully';
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in insert_mrl_line_items: %, SQLSTATE: %', SQLERRM, SQLSTATE;
END;
$$;