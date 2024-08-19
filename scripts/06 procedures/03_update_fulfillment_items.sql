-- update fulfillment items procedure
-- version 0.9.10

CREATE OR REPLACE PROCEDURE update_fulfillment_items(
    batch_data jsonb,
    update_source TEXT,
    OUT summary TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    item jsonb;
    current_user_id INT;
    current_role_id INT;
    v_record_count INT := 0;
    v_success_count INT := 0;
    v_error_count INT := 0;
    v_multiple_records_count INT := 0;
    v_error_messages TEXT := '';
    v_batch_size INT := 1000; -- Process in batches of 1000 records
    v_total_records INT;
    v_batch_start INT;
    v_batch_end INT;
    v_fulfillment_count INT;
BEGIN
    RAISE LOG 'update_fulfillment_items started';
    RAISE LOG 'Update source: %', update_source;
    RAISE LOG 'batch_data type: %', pg_typeof(batch_data);
    RAISE LOG 'batch_data size: % bytes', octet_length(batch_data::text);
    RAISE LOG 'First 1000 characters of batch_data: %', left(batch_data::text, 1000);
    
    -- Get session variables
    current_user_id := current_setting('myapp.user_id', true)::INT;
    current_role_id := current_setting('myapp.role_id', true)::INT;

    RAISE LOG 'Current user ID from session: %, Current role ID from session: %', current_user_id, current_role_id;

    -- Validate batch_data
    IF batch_data IS NULL OR jsonb_typeof(batch_data) != 'array' THEN
        RAISE LOG 'Invalid batch_data: not a JSON array or is NULL. Data: %', batch_data;
        summary := 'Invalid batch_data: not a JSON array or is NULL';
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
                -- Check how many fulfillment records exist for this jcn/twcode combination
                SELECT COUNT(*) INTO v_fulfillment_count
                FROM fulfillment_items fi
                JOIN MRL_line_items mli ON fi.order_line_item_id = mli.order_line_item_id
                WHERE mli.jcn = (item->>'jcn')::TEXT AND mli.twcode = (item->>'twcode')::TEXT;

                IF v_fulfillment_count = 0 THEN
                    -- Log error if no fulfillment record found
                    v_error_count := v_error_count + 1;
                    v_error_messages := v_error_messages || 'Error in record ' || v_record_count || ': No fulfillment record found for JCN: ' || (item->>'jcn')::TEXT || ', TWCODE: ' || (item->>'twcode')::TEXT || E'\n';
                ELSIF v_fulfillment_count = 1 THEN
                    -- Update the single fulfillment record
                    UPDATE fulfillment_items fi
                    SET 
                        status_id = (item->>'status_id')::INT,
                        edd_to_ches = (item->>'edd_to_ches')::DATE,
                        carrier = item->>'carrier',
                        updated_by = current_user_id,
                        updated_at = CURRENT_TIMESTAMP,
                        update_source = update_source
                    FROM MRL_line_items mli
                    WHERE fi.order_line_item_id = mli.order_line_item_id
                      AND mli.jcn = (item->>'jcn')::TEXT 
                      AND mli.twcode = (item->>'twcode')::TEXT;

                    v_success_count := v_success_count + 1;
                    PERFORM log_audit('UPDATE'::TEXT, fi.order_line_item_id, fi.fulfillment_item_id, 'Updated fulfillment item'::TEXT, update_source);
                ELSE
                    -- Log if multiple fulfillment records found
                    v_multiple_records_count := v_multiple_records_count + 1;
                    v_error_messages := v_error_messages || 'Warning in record ' || v_record_count || ': Multiple fulfillment records (' || v_fulfillment_count || ') found for JCN: ' || (item->>'jcn')::TEXT || ', TWCODE: ' || (item->>'twcode')::TEXT || E'\n';
                END IF;

            EXCEPTION 
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    v_error_messages := v_error_messages || 'Error in record ' || v_record_count || ': ' || SQLERRM || E'\n';
                    RAISE LOG 'Error updating fulfillment item: %, SQLSTATE: %', SQLERRM, SQLSTATE;
                    RAISE LOG 'Problematic item: %', item;
            END;
        END LOOP;

        RAISE LOG 'Batch %-% completed. Successes: %, Errors: %, Multiple Records: %', 
                  v_batch_start, v_batch_end, v_success_count, v_error_count, v_multiple_records_count;
    END LOOP;

    -- Log the final results
    RAISE LOG 'update_fulfillment_items completed. Total: %, Success: %, Errors: %, Multiple Records: %', 
              v_record_count, v_success_count, v_error_count, v_multiple_records_count;
    IF v_error_count > 0 OR v_multiple_records_count > 0 THEN
        RAISE LOG 'Error and warning messages: %', v_error_messages;
    END IF;

    -- Set the summary
    summary := format('Operation completed. Total: %s, Success: %s, Errors: %s, Multiple Records: %s', 
                      v_record_count, v_success_count, v_error_count, v_multiple_records_count);

    -- Renew the session after all processing is complete
    PERFORM renew_session(current_setting('myapp.session_id')::uuid, '1 hour'::interval);

EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Unhandled exception in update_fulfillment_items: %, SQLSTATE: %, batch_data sample: %', SQLERRM, SQLSTATE, (SELECT jsonb_pretty(jsonb_agg(e)) FROM (SELECT e FROM jsonb_array_elements(batch_data) e LIMIT 5) s);
    summary := 'Unhandled exception: ' || SQLERRM;
END;
$$;

