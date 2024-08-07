

-- version 0.7.14.39
-- Added more detailed logging for log audit
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
    v_availability_identifier INT;
    
BEGIN
    RAISE LOG 'insert_mrl_line_items started';
    RAISE LOG 'Current database user: %', current_user;
    RAISE LOG 'Current role: %', current_role;

    -- Retrieve and log session variables
    RAISE LOG 'Attempting to retrieve session variables';
    
    -- Get session variables
    current_user_id := current_setting('myapp.user_id', true)::INT;
    current_role_id := current_setting('myapp.role_id', true)::INT;

    -- Log current user and role information
    RAISE LOG 'Current user ID from session: %, Current role ID from session: %', current_user_id, current_role_id;
    
    -- Additional check for role
    RAISE LOG 'Is current user a member of kppo_admin_user role: %', (SELECT TRUE FROM pg_roles WHERE rolname = 'kppo_admin_user' AND pg_has_role(current_user, oid, 'member'));

    RAISE LOG 'Batch data: %', batch_data;
    RAISE LOG 'Update source: %', update_source;

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
            v_availability_identifier := (item->>'availability_identifier')::INT;

            RAISE LOG 'Extracted values: jcn=%, twcode=%, qty=%, market_research_up=%, market_research_ep=%, request_date=%, rdd=%, inquiry_status=%, availability_identifier=%',
                         v_jcn, v_twcode, v_qty, v_market_research_up, v_market_research_ep, v_request_date, v_rdd, v_inquiry_status, v_availability_identifier;

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
                v_market_research_up, v_market_research_ep, v_availability_identifier,
                v_request_date, v_rdd, item->>'pri', item->>'swlin', item->>'hull_or_shop',
                item->>'suggested_source', item->>'mfg_cage', item->>'apl',
                item->>'nha_equipment_system', item->>'nha_model', item->>'nha_serial',
                item->>'techmanual', item->>'dwg_pc', item->>'requestor_remarks',
                v_inquiry_status, current_user_id, update_source
            ) RETURNING order_line_item_id INTO new_order_line_item_id;

            RAISE LOG 'Inserted new MRL line item with ID: %', new_order_line_item_id;

            -- Call the log_audit function
            BEGIN
                 RAISE LOG 'Calling log_audit function';
                 PERFORM log_audit(
                        'INSERT'::TEXT, 
                        new_order_line_item_id,
                        NULL::INT,
                        'Inserted new MRL line item'::TEXT,
                        update_source
                  );
                  RAISE LOG 'log_audit function call completed';
            EXCEPTION WHEN OTHERS THEN
                  RAISE LOG 'Error calling log_audit: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                  RAISE LOG 'Problematic data: new_order_line_item_id=%, update_source=%',
                             new_order_line_item_id, update_source;
            END;
        EXCEPTION WHEN OTHERS THEN
            RAISE LOG 'Error inserting MRL line item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
            RAISE LOG 'Current user ID: %, Current role ID: %', current_user_id, current_role_id;
            RAISE LOG 'Current database user: %', current_user;
            RAISE LOG 'Current role: %', current_role;
            RAISE LOG 'Problematic item: %', item;
        END;

        RAISE LOG 'Finished processing item';
    END LOOP;

    RAISE LOG 'insert_mrl_line_items completed successfully';
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in insert_mrl_line_items: %, SQLSTATE: %', SQLERRM, SQLSTATE;
    RAISE LOG 'Current user ID: %, Current role ID: %', current_user_id, current_role_id;
    RAISE LOG 'Current database user: %', current_user;
    RAISE LOG 'Current role: %', current_role;
END;
$$;
