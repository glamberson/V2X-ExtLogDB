-- version 0.9.43

CREATE OR REPLACE PROCEDURE insert_mrl_line_items(
    batch_data jsonb,
    update_source TEXT,
    OUT summary JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    item jsonb;
    current_user_id INT;
    current_role_id INT;
    new_order_line_item_id INT;
    v_record_count INT := 0;
    v_success_count INT := 0;
    v_error_count INT := 0;
    v_duplicate_count INT := 0;
    v_batch_size INT := 1000;
    v_total_records INT;
    v_batch_start INT;
    v_batch_end INT;
    v_batch_id UUID;
BEGIN
    RAISE LOG 'insert_mrl_line_items started';
    RAISE LOG 'Update source: %', update_source;
    RAISE LOG 'batch_data type: %', pg_typeof(batch_data);
    RAISE LOG 'batch_data size: % bytes', octet_length(batch_data::text);
    RAISE LOG 'First 1000 characters of batch_data: %', left(batch_data::text, 1000);
    
    -- Generate a unique batch ID
    v_batch_id := gen_random_uuid();
    
    -- Get session variables
    current_user_id := current_setting('myapp.user_id', true)::INT;
    current_role_id := current_setting('myapp.role_id', true)::INT;

    RAISE LOG 'Current user ID from session: %, Current role ID from session: %', current_user_id, current_role_id;

    -- Validate batch_data
    IF batch_data IS NULL OR jsonb_typeof(batch_data) != 'array' THEN
        RAISE LOG 'Invalid batch_data: not a JSON array or is NULL. Data: %', batch_data;
        summary := jsonb_build_object('status', 'error', 'message', 'Invalid batch_data: not a JSON array or is NULL');
        RETURN;
    END IF;

    -- Log the number of records and a sample in the JSON data
    v_total_records := jsonb_array_length(batch_data);
    RAISE LOG 'Number of records in JSON data: %', v_total_records;
    RAISE LOG 'Sample of batch_data (first 3 elements): %', (SELECT jsonb_pretty(jsonb_agg(e)) FROM (SELECT e FROM jsonb_array_elements(batch_data) e LIMIT 3) s);

    -- Process records in batches
    FOR v_batch_start IN 0..v_total_records-1 BY v_batch_size LOOP
        v_batch_end := LEAST(v_batch_start + v_batch_size - 1, v_total_records - 1);
        
        RAISE LOG 'Starting batch %-%', v_batch_start, v_batch_end;

        FOR i IN v_batch_start..v_batch_end LOOP
            item := batch_data->i;
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

            EXCEPTION 
                WHEN unique_violation THEN
                    v_duplicate_count := v_duplicate_count + 1;
                    RAISE LOG 'Duplicate record found for JCN: %, TWCODE: %', item->>'jcn', item->>'twcode';
                    INSERT INTO import_error_log (
                        batch_id, operation_type, source_file_line_number, jcn, twcode,
                        error_type, error_message, record_data
                    ) VALUES (
                        v_batch_id, 'MRL_INSERT', v_record_count, item->>'jcn', item->>'twcode',
                        'ERROR', 'Duplicate record', item
                    );
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    RAISE LOG 'Error inserting MRL line item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                    RAISE LOG 'Problematic item: %', item;
                    INSERT INTO import_error_log (
                        batch_id, operation_type, source_file_line_number, jcn, twcode,
                        error_type, error_message, record_data
                    ) VALUES (
                        v_batch_id, 'MRL_INSERT', v_record_count, item->>'jcn', item->>'twcode',
                        'ERROR', SQLERRM, item
                    );
            END;
        END LOOP;

        RAISE LOG 'Batch %-% completed. Successes: %, Duplicates: %, Errors: %', 
                  v_batch_start, v_batch_end, v_success_count, v_duplicate_count, v_error_count;
    END LOOP;

    -- Log the final results
    RAISE LOG 'insert_mrl_line_items completed. Total: %, Success: %, Duplicates: %, Errors: %', 
              v_record_count, v_success_count, v_duplicate_count, v_error_count;

    -- Set the summary
    summary := jsonb_build_object(
        'status', 'completed',
        'batch_id', v_batch_id,
        'total', v_record_count,
        'success', v_success_count,
        'duplicates', v_duplicate_count,
        'errors', v_error_count,
        'operation', 'insert_mrl_line_items',
        'update_source', update_source,
        'timestamp', current_timestamp
    );

    -- Renew the session after all processing is complete
    PERFORM renew_session(current_setting('myapp.session_id')::uuid, '1 hour'::interval);

EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in insert_mrl_line_items: %, SQLSTATE: %, batch_data sample: %', SQLERRM, SQLSTATE, (SELECT jsonb_pretty(jsonb_agg(e)) FROM (SELECT e FROM jsonb_array_elements(batch_data) e LIMIT 5) s);
    summary := jsonb_build_object(
        'status', 'error', 
        'message', 'Unhandled exception: ' || SQLERRM,
        'operation', 'insert_mrl_line_items',
        'update_source', update_source,
        'timestamp', current_timestamp
    );
END;
$$;

