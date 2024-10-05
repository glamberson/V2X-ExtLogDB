-- update fulfillment items procedure
-- version 0.9.43

CREATE OR REPLACE PROCEDURE update_fulfillment_items(
    batch_data jsonb,
    update_source TEXT,
    OUT summary JSONB
)
LANGUAGE plpgsql AS $$
DECLARE
    item jsonb;
    current_user_id INT;
    current_role_id INT;
    v_record_count INT := 0;
    v_success_count INT := 0;
    v_error_count INT := 0;
    v_warning_count INT := 0;
    v_multiple_records_count INT := 0;
    v_batch_size INT := 1000;
    v_total_records INT;
    v_batch_start INT;
    v_batch_end INT;
    v_fulfillment_count INT;
    v_existing_record fulfillment_items%ROWTYPE;
    v_changes jsonb;
    v_field text;
    v_old_value text;
    v_new_value text;
    v_update_fields jsonb := '{}'::jsonb;
    v_allowed_fields text[] := ARRAY[
        'shipdoc_tcn', 'v2x_ship_no', 'booking', 'vessel', 'container', 'carrier',
        'sail_date', 'edd_to_ches', 'rcd_v2x_date', 'lot_id', 'triwall',
        'lsc_on_hand_date', 'arr_lsc_egypt', 'milstrip_req_no', 'edd_egypt'
    ];
    v_update_query text;
    v_batch_id UUID;
BEGIN
    RAISE LOG 'update_fulfillment_items started';
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
                -- Log the current item being processed
                RAISE LOG 'Processing item %: %', v_record_count, jsonb_pretty(item);

                -- Check how many fulfillment records exist for this jcn/twcode combination
                SELECT COUNT(*) INTO v_fulfillment_count
                FROM fulfillment_items fi
                JOIN MRL_line_items mli ON fi.order_line_item_id = mli.order_line_item_id
                WHERE mli.jcn = (item->>'jcn')::TEXT AND mli.twcode = (item->>'twcode')::TEXT;

                RAISE LOG 'Found % fulfillment records for JCN: %, TWCODE: %', v_fulfillment_count, (item->>'jcn')::TEXT, (item->>'twcode')::TEXT;

                IF v_fulfillment_count = 0 THEN
                    -- Log error if no fulfillment record found
                    v_error_count := v_error_count + 1;
                    INSERT INTO import_error_log (
                        batch_id, operation_type, source_file_line_number, jcn, twcode,
                        error_type, error_message, record_data
                    ) VALUES (
                        v_batch_id, 'FULFILLMENT_UPDATE', v_record_count, item->>'jcn', item->>'twcode',
                        'ERROR', 'No fulfillment record found', item
                    );
                ELSIF v_fulfillment_count = 1 THEN
                    -- Fetch existing record
                    SELECT fi.* INTO v_existing_record
                    FROM fulfillment_items fi
                    JOIN MRL_line_items mli ON fi.order_line_item_id = mli.order_line_item_id
                    WHERE mli.jcn = (item->>'jcn')::TEXT AND mli.twcode = (item->>'twcode')::TEXT;

                    -- Initialize changes
                    v_changes := '{}'::jsonb;
                    v_update_fields := '{}'::jsonb;

                    -- Check for changes in allowed fields
                    FOREACH v_field IN ARRAY v_allowed_fields
                    LOOP
                        IF item ? v_field THEN  -- Check if the field exists in the input data
                            EXECUTE format('SELECT $1->>%L', v_field) USING item INTO v_new_value;
                            EXECUTE format('SELECT $1.%I::text', v_field) USING v_existing_record INTO v_old_value;

                            IF v_new_value IS NOT NULL AND v_new_value != '' THEN
                                IF v_old_value IS NULL OR v_old_value = '' OR v_new_value != v_old_value THEN
                                    v_changes := v_changes || jsonb_build_object(v_field, jsonb_build_object('old', v_old_value, 'new', v_new_value));
                                    v_update_fields := v_update_fields || jsonb_build_object(v_field, v_new_value);
                                END IF;
                            END IF;
                        END IF;
                    END LOOP;

                    RAISE LOG 'Changes for record %: %', v_record_count, jsonb_pretty(v_changes);

                    -- Log warnings for all changes
                    IF jsonb_typeof(v_changes) != 'null' AND v_changes != '{}'::jsonb THEN
                        v_warning_count := v_warning_count + 1;
                        INSERT INTO import_error_log (
                            batch_id, operation_type, source_file_line_number, jcn, twcode,
                            order_line_item_id, fulfillment_item_id, error_type, error_message, record_data
                        ) VALUES (
                            v_batch_id, 'FULFILLMENT_UPDATE', v_record_count, item->>'jcn', item->>'twcode',
                            v_existing_record.order_line_item_id, v_existing_record.fulfillment_item_id,
                            'WARNING', 'Data modified', 
                            jsonb_build_object('original', to_jsonb(v_existing_record), 'changes', v_changes, 'new', item)
                        );
                    END IF;

                    -- Update the fulfillment record if there are changes
                    IF jsonb_typeof(v_update_fields) != 'null' AND v_update_fields != '{}'::jsonb THEN
                        RAISE LOG 'Updating record % with fields: %', v_record_count, jsonb_pretty(v_update_fields);

                        -- Construct the update query
                        v_update_query := 'UPDATE fulfillment_items fi SET ';

                        FOR v_field IN SELECT jsonb_object_keys(v_update_fields)
                        LOOP
                            v_update_query := v_update_query || format('%I = %s, ', v_field, quote_literal(v_update_fields->>v_field));
                        END LOOP;

                        v_update_query := v_update_query || format('updated_by = %s, updated_at = CURRENT_TIMESTAMP, update_source = %s ', 
                                                                   quote_literal(current_user_id), quote_literal(update_source));
                        v_update_query := v_update_query || 'FROM MRL_line_items mli ';
                        v_update_query := v_update_query || format('WHERE fi.order_line_item_id = mli.order_line_item_id AND mli.jcn = %s AND mli.twcode = %s',
                                                                   quote_literal((item->>'jcn')::TEXT), quote_literal((item->>'twcode')::TEXT));

                        -- Log the UPDATE query
                        RAISE LOG 'Executing UPDATE query: %', v_update_query;

                        -- Execute the update query
                        EXECUTE v_update_query;

                        v_success_count := v_success_count + 1;
                        PERFORM log_audit('UPDATE'::TEXT, v_existing_record.order_line_item_id, v_existing_record.fulfillment_item_id, 
                                          format('Updated fulfillment item: %s. Changes: %s', 
                                                 v_update_fields, v_changes)::TEXT, 
                                          update_source);
                    ELSE
                        -- No changes were made
                        RAISE LOG 'No changes for record %s (JCN: %s, TWCODE: %s)', 
                            v_record_count, (item->>'jcn')::TEXT, (item->>'twcode')::TEXT;
                    END IF;

                ELSE
                    -- Log if multiple fulfillment records found
                    v_multiple_records_count := v_multiple_records_count + 1;
                    INSERT INTO import_error_log (
                        batch_id, operation_type, source_file_line_number, jcn, twcode,
                        error_type, error_message, record_data
                    ) VALUES (
                        v_batch_id, 'FULFILLMENT_UPDATE', v_record_count, item->>'jcn', item->>'twcode',
                        'WARNING', format('Multiple fulfillment records (%s) found', v_fulfillment_count), item
                    );
                END IF;

            EXCEPTION 
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    INSERT INTO import_error_log (
                        batch_id, operation_type, source_file_line_number, jcn, twcode,
                        error_type, error_message, record_data
                    ) VALUES (
                        v_batch_id, 'FULFILLMENT_UPDATE', v_record_count, item->>'jcn', item->>'twcode',
                        'ERROR', SQLERRM, item
                    );
                    RAISE LOG 'Error updating fulfillment item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                    RAISE LOG 'Problematic item: %', jsonb_pretty(item);
            END;
        END LOOP;

        RAISE LOG 'Batch %-% completed. Successes: %, Errors: %, Warnings: %, Multiple Records: %', 
                  v_batch_start, v_batch_end, v_success_count, v_error_count, v_warning_count, v_multiple_records_count;
    END LOOP;

    -- Log the final results
    RAISE LOG 'update_fulfillment_items completed. Total: %, Success: %, Errors: %, Warnings: %, Multiple Records: %', 
              v_record_count, v_success_count, v_error_count, v_warning_count, v_multiple_records_count;

    -- Set the summary
    summary := jsonb_build_object(
        'status', 'completed',
        'batch_id', v_batch_id,
        'total', v_record_count,
        'success', v_success_count,
        'errors', v_error_count,
        'warnings', v_warning_count,
        'multiple_records', v_multiple_records_count,
        'operation', 'update_fulfillment_items',
        'update_source', update_source,
        'timestamp', current_timestamp
    );

    -- Renew the session after all processing is complete
    PERFORM renew_session(current_setting('myapp.session_id')::uuid, '1 hour'::interval);

EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in update_fulfillment_items: %, SQLSTATE: %, batch_data sample: %', SQLERRM, SQLSTATE, (SELECT jsonb_pretty(jsonb_agg(e)) FROM (SELECT e FROM jsonb_array_elements(batch_data) e LIMIT 5) s);
    summary := jsonb_build_object(
        'status', 'error', 
        'message', 'Unhandled exception: ' || SQLERRM,
        'operation', 'update_fulfillment_items',
        'update_source', update_source,
        'timestamp', current_timestamp
    );
END;
$$;

