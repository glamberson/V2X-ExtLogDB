-- version 0.8.15
CREATE OR REPLACE PROCEDURE insert_mrl_line_items(
    batch_data text,
    update_source TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    parsed_data jsonb;
    item jsonb;
    current_user_id INT;
    current_role_id INT;
    new_order_line_item_id INT;
    v_record_count INT := 0;
    v_success_count INT := 0;
    v_error_count INT := 0;
    v_error_messages TEXT := '';
BEGIN
    RAISE LOG 'insert_mrl_line_items started';
    RAISE LOG 'Update source: %', update_source;
    
    -- Get session variables
    current_user_id := current_setting('myapp.user_id', true)::INT;
    current_role_id := current_setting('myapp.role_id', true)::INT;

    RAISE LOG 'Current user ID from session: %, Current role ID from session: %', current_user_id, current_role_id;

    -- Safely parse the JSON data
    BEGIN
        parsed_data := batch_data::jsonb;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid JSON data: %', SQLERRM;
    END;

    -- Validate batch_data
    IF parsed_data IS NULL OR jsonb_typeof(parsed_data) != 'array' THEN
        RAISE EXCEPTION 'Invalid batch_data: not a JSON array or is NULL';
    END IF;

    -- Log the number of records in the JSON data
    RAISE LOG 'Number of records in JSON data: %', jsonb_array_length(parsed_data);

    -- Start a subtransaction
    BEGIN
        -- Loop through each item in the JSONB array
        FOR item IN SELECT * FROM jsonb_array_elements(parsed_data)
        LOOP
            v_record_count := v_record_count + 1;
            BEGIN
                -- Insert into MRL_line_items table
                INSERT INTO MRL_line_items (
                    jcn, twcode, nomenclature, cog, fsc, niin, part_no, qty, ui,
                    market_research_up, market_research_ep, availability_identifier,
                    request_date, rdd, pri, swlin, hull_or_shop, suggested_source,
                    mfg_cage, apl, nha_equipment_system, nha_model, nha_serial,
                    techmanual, dwg_pc, requestor_remarks, inquiry_status,
                    created_by, update_source
                ) VALUES (
                    (item->>'jcn')::TEXT,
                    (item->>'twcode')::TEXT,
                    (item->>'nomenclature')::TEXT,
                    (item->>'cog')::TEXT,
                    (item->>'fsc')::TEXT,
                    (item->>'niin')::TEXT,
                    (item->>'part_no')::TEXT,
                    (item->>'qty')::INT,
                    (item->>'ui')::TEXT,
                    (item->>'market_research_up')::NUMERIC,
                    (item->>'market_research_ep')::NUMERIC,
                    (item->>'availability_identifier')::INT,
                    (item->>'request_date')::DATE,
                    (item->>'rdd')::DATE,
                    (item->>'pri')::TEXT,
                    (item->>'swlin')::TEXT,
                    (item->>'hull_or_shop')::TEXT,
                    (item->>'suggested_source')::TEXT,
                    (item->>'mfg_cage')::TEXT,
                    (item->>'apl')::TEXT,
                    (item->>'nha_equipment_system')::TEXT,
                    (item->>'nha_model')::TEXT,
                    (item->>'nha_serial')::TEXT,
                    (item->>'techmanual')::TEXT,
                    (item->>'dwg_pc')::TEXT,
                    (item->>'requestor_remarks')::TEXT,
                    (item->>'inquiry_status')::BOOLEAN,
                    current_user_id,
                    update_source
                ) RETURNING order_line_item_id INTO new_order_line_item_id;

                v_success_count := v_success_count + 1;
                PERFORM log_audit('INSERT'::TEXT, new_order_line_item_id, NULL::INT, 'Inserted new MRL line item'::TEXT, update_source);

            EXCEPTION WHEN OTHERS THEN
                v_error_count := v_error_count + 1;
                v_error_messages := v_error_messages || 'Error in record ' || v_record_count || ': ' || SQLERRM || E'\n';
                RAISE LOG 'Error inserting MRL line item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                RAISE LOG 'Problematic item: %', item;
            END;
        END LOOP;

    EXCEPTION WHEN OTHERS THEN
        v_error_messages := v_error_messages || 'Error processing batch: ' || SQLERRM || E'\n';
        RAISE LOG 'Error processing batch: %, SQLSTATE: %', SQLERRM, SQLSTATE;
    END;

    -- Log the final results
    RAISE LOG 'insert_mrl_line_items completed. Total: %, Success: %, Errors: %', v_record_count, v_success_count, v_error_count;
    IF v_error_count > 0 THEN
        RAISE LOG 'Error messages: %', v_error_messages;
    END IF;

    -- Raise an exception if there were any errors, but include the success count in the message
    IF v_error_count > 0 THEN
        RAISE EXCEPTION 'Some records failed to insert. Total: %, Success: %, Errors: %. Error messages: %', 
                        v_record_count, v_success_count, v_error_count, v_error_messages;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in insert_mrl_line_items: %, SQLSTATE: %', SQLERRM, SQLSTATE;
    RAISE;
END;
$$;

