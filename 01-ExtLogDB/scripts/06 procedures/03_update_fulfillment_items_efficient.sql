-- Version 0.11.0
-- Updated Stored Procedure with additional logging and data verification

CREATE OR REPLACE PROCEDURE update_fulfillment_items_efficient(
    IN batch_data JSONB,
    IN v_update_source TEXT,
    OUT summary JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Counters for summary
    v_success_count INT := 0;
    v_error_count INT := 0;
    v_warning_count INT := 0;

    -- Batch processing variables
    v_batch_size INT := 1000; -- Define batch size
    v_total_records INT;
    v_batch_start INT;
    v_batch_id UUID;
    v_updated_rows INT;
    v_logged_warnings INT;

    -- Status mapping
    status_map JSONB;

    -- Exception handling
    original_session_replication_role TEXT;

    -- Variables to capture error details
    v_error_message TEXT;
    v_error_detail TEXT;
    v_error_hint TEXT;
    v_sqlstate TEXT;
BEGIN
    -- Generate a unique batch ID
    v_batch_id := gen_random_uuid();
    RAISE NOTICE 'Generated batch ID: %', v_batch_id;

    -- Validate batch_data
    IF batch_data IS NULL OR jsonb_typeof(batch_data) != 'array' THEN
        RAISE EXCEPTION 'Invalid batch_data: not a JSON array or is NULL';
    END IF;

    -- Get total number of records
    v_total_records := jsonb_array_length(batch_data);
    RAISE NOTICE 'Total records to process: %', v_total_records;

    -- Create temporary table for updates
    CREATE TEMP TABLE temp_fulfillment_updates (
        jcn VARCHAR,
        twcode VARCHAR,
        shipdoc_tcn VARCHAR,
        v2x_ship_no VARCHAR,
        booking VARCHAR,
        vessel VARCHAR,
        container VARCHAR,
        carrier VARCHAR,
        sail_date DATE,
        edd_to_ches DATE,
        edd_egypt DATE,
        rcd_v2x_date DATE,
        lot_id VARCHAR,
        triwall VARCHAR,
        lsc_on_hand_date DATE,
        arr_lsc_egypt DATE,
        milstrip_req_no VARCHAR,
        comments TEXT,
        update_source TEXT
    ) ON COMMIT DROP;

    -- Create temporary table for multiple records
    CREATE TEMP TABLE temp_multiple_records (
        jcn VARCHAR,
        twcode VARCHAR,
        fulfillment_item_ids INT[],
        order_line_item_ids INT[],
        batch_id UUID
    ) ON COMMIT DROP;

    -- Pre-fetch all relevant status_id mappings into a JSONB object
    SELECT jsonb_object_agg(status_name, status_id) INTO status_map
    FROM statuses
    WHERE status_name IN (
        'ON HAND EGYPT', 'ARR EGYPT', 'EN ROUTE TO EGYPT', 'FREIGHT FORWARDER',
        'READY TO SHIP', 'PROC CHES WH', 'RCD CHES WH', 'ON ORDER',
        'INIT PROCESS', 'NOT ORDERED'
    );

    -- Store the original session_replication_role
    original_session_replication_role := current_setting('session_replication_role', true);

    -- Set session_replication_role to 'replica' to bypass triggers
    PERFORM set_config('session_replication_role', 'replica', true);
    RAISE NOTICE 'session_replication_role set to replica. Triggers are bypassed during bulk updates.';

    -- Process records in batches
    FOR v_batch_start IN 0..v_total_records-1 BY v_batch_size LOOP
        RAISE NOTICE 'Processing batch starting at record: %', v_batch_start;

        -- Truncate temporary tables
        TRUNCATE TABLE temp_fulfillment_updates, temp_multiple_records;

        -- Insert batch data into temporary table
        INSERT INTO temp_fulfillment_updates
        SELECT
            NULLIF(item.value ->> 'jcn', '') AS jcn,
            NULLIF(item.value ->> 'twcode', '') AS twcode,
            NULLIF(item.value ->> 'shipdoc_tcn', '') AS shipdoc_tcn,
            NULLIF(item.value ->> 'v2x_ship_no', '') AS v2x_ship_no,
            NULLIF(item.value ->> 'booking', '') AS booking,
            NULLIF(item.value ->> 'vessel', '') AS vessel,
            NULLIF(item.value ->> 'container', '') AS container,
            NULLIF(item.value ->> 'carrier', '') AS carrier,
            NULLIF(item.value ->> 'sail_date', '')::DATE AS sail_date,
            NULLIF(item.value ->> 'edd_to_ches', '')::DATE AS edd_to_ches,
            NULLIF(item.value ->> 'edd_egypt', '')::DATE AS edd_egypt,
            NULLIF(item.value ->> 'rcd_v2x_date', '')::DATE AS rcd_v2x_date,
            NULLIF(item.value ->> 'lot_id', '') AS lot_id,
            NULLIF(item.value ->> 'triwall', '') AS triwall,
            NULLIF(item.value ->> 'lsc_on_hand_date', '')::DATE AS lsc_on_hand_date,
            NULLIF(item.value ->> 'arr_lsc_egypt', '')::DATE AS arr_lsc_egypt,
            NULLIF(item.value ->> 'milstrip_req_no', '') AS milstrip_req_no,
            NULLIF(item.value ->> 'comments', '') AS comments,
            v_update_source AS update_source
        FROM jsonb_array_elements(batch_data) WITH ORDINALITY AS item(value, index)
        WHERE index > v_batch_start AND index <= v_batch_start + v_batch_size;

        -- Log number of records inserted into temp_fulfillment_updates
        RAISE NOTICE 'Inserted % records into temp_fulfillment_updates', (SELECT COUNT(*) FROM temp_fulfillment_updates);

        -- Log sample data from temp_fulfillment_updates
        RAISE NOTICE 'Sample record from temp_fulfillment_updates: %', (SELECT row_to_json(tfu) FROM temp_fulfillment_updates tfu LIMIT 1);

        -- Detect fulfillment items with multiple records (same jcn and twcode)
        WITH duplicate_records AS (
            SELECT 
                tu.jcn,
                tu.twcode,
                array_agg(fi.fulfillment_item_id) AS fulfillment_item_ids,
                array_agg(fi.order_line_item_id) AS order_line_item_ids,
                COUNT(*) AS cnt
            FROM temp_fulfillment_updates tu
            JOIN MRL_line_items mli ON LOWER(TRIM(tu.jcn)) = LOWER(TRIM(mli.jcn))
                                   AND LOWER(TRIM(tu.twcode)) = LOWER(TRIM(mli.twcode))
            JOIN fulfillment_items fi ON fi.order_line_item_id = mli.order_line_item_id
            GROUP BY tu.jcn, tu.twcode
        )
        INSERT INTO temp_multiple_records (
            jcn, twcode, fulfillment_item_ids, order_line_item_ids, batch_id
        )
        SELECT dr.jcn, dr.twcode, dr.fulfillment_item_ids, dr.order_line_item_ids, v_batch_id
        FROM duplicate_records dr
        WHERE dr.cnt > 1;

        -- Log number of fulfillment items with multiple records detected
        v_logged_warnings := (SELECT COUNT(*) FROM temp_multiple_records);
        RAISE NOTICE 'Detected % fulfillment items with multiple records (jcn and twcode)', v_logged_warnings;

        -- Log warnings for multiple fulfillment records
        INSERT INTO import_error_log (
            batch_id, operation_type, source_file_line_number, jcn, twcode,
            error_type, error_message, record_data, created_at
        )
        SELECT
            v_batch_id,
            'FULFILLMENT_UPDATE',
            NULL, -- No specific source file line number
            mr.jcn,
            mr.twcode,
            'WARNING',
            'Multiple fulfillment records found for this JCN and TWCODE',
            row_to_json(tu.*)::jsonb,
            NOW()
        FROM temp_multiple_records mr
        JOIN temp_fulfillment_updates tu ON tu.jcn = mr.jcn AND tu.twcode = mr.twcode;

        RAISE NOTICE 'Logged % warning records for multiple fulfillment items.', v_logged_warnings;

        -- Increment warning count
        v_warning_count := v_warning_count + v_logged_warnings;

        -- Create temporary table to store updated_fulfillments data
        CREATE TEMP TABLE temp_updated_fulfillments ON COMMIT DROP AS
        WITH to_update AS (
            SELECT tu.*, fi.fulfillment_item_id, fi.order_line_item_id
            FROM temp_fulfillment_updates tu
            JOIN MRL_line_items mli ON LOWER(TRIM(tu.jcn)) = LOWER(TRIM(mli.jcn))
                                   AND LOWER(TRIM(tu.twcode)) = LOWER(TRIM(mli.twcode))
            JOIN fulfillment_items fi ON fi.order_line_item_id = mli.order_line_item_id
            LEFT JOIN temp_multiple_records mr ON tu.jcn = mr.jcn AND tu.twcode = mr.twcode
            WHERE mr.jcn IS NULL -- Exclude duplicates
        ),
        updated_fulfillments AS (
            SELECT 
                tu.fulfillment_item_id,
                tu.shipdoc_tcn,
                tu.v2x_ship_no,
                tu.booking,
                tu.vessel,
                tu.container,
                tu.carrier,
                tu.sail_date,
                tu.edd_to_ches,
                tu.edd_egypt,
                tu.rcd_v2x_date,
                tu.lot_id,
                tu.triwall,
                tu.lsc_on_hand_date,
                tu.arr_lsc_egypt,
                tu.milstrip_req_no,
                tu.comments,
                tu.update_source,
                CASE
                    WHEN tu.lsc_on_hand_date IS NOT NULL THEN (status_map->>'ON HAND EGYPT')::INT
                    WHEN tu.arr_lsc_egypt IS NOT NULL THEN (status_map->>'ARR EGYPT')::INT
                    WHEN tu.sail_date IS NOT NULL AND tu.sail_date <= CURRENT_DATE THEN (status_map->>'EN ROUTE TO EGYPT')::INT
                    WHEN tu.sail_date IS NOT NULL AND tu.sail_date > CURRENT_DATE THEN (status_map->>'FREIGHT FORWARDER')::INT
                    WHEN tu.shipdoc_tcn IS NOT NULL OR tu.v2x_ship_no IS NOT NULL OR tu.booking IS NOT NULL OR tu.vessel IS NOT NULL OR tu.container IS NOT NULL THEN (status_map->>'READY TO SHIP')::INT
                    WHEN tu.lot_id IS NOT NULL AND tu.triwall IS NOT NULL THEN (status_map->>'PROC CHES WH')::INT
                    WHEN tu.rcd_v2x_date IS NOT NULL THEN (status_map->>'RCD CHES WH')::INT
                    WHEN tu.edd_to_ches IS NOT NULL THEN (status_map->>'ON ORDER')::INT
                    WHEN tu.milstrip_req_no IS NOT NULL THEN (status_map->>'INIT PROCESS')::INT
                    ELSE (status_map->>'NOT ORDERED')::INT
                END AS new_status_id
            FROM to_update tu
        )
        SELECT * FROM updated_fulfillments;

        -- Log number of records in temp_updated_fulfillments
        RAISE NOTICE 'temp_updated_fulfillments contains % records.', (SELECT COUNT(*) FROM temp_updated_fulfillments);

        -- Log sample data from temp_updated_fulfillments
        RAISE NOTICE 'Sample record from temp_updated_fulfillments: %', (SELECT row_to_json(tuf) FROM temp_updated_fulfillments tuf LIMIT 1);

        -- Now update fulfillment_items using temp_updated_fulfillments
        UPDATE fulfillment_items fi
        SET
            shipdoc_tcn = LEFT(tuf.shipdoc_tcn, 30),
            v2x_ship_no = LEFT(tuf.v2x_ship_no, 20),
            booking = LEFT(tuf.booking, 20),
            vessel = LEFT(tuf.vessel, 30),
            container = LEFT(tuf.container, 25),
            carrier = LEFT(tuf.carrier, 50),
            sail_date = tuf.sail_date,
            edd_to_ches = tuf.edd_to_ches,
            edd_egypt = tuf.edd_egypt,
            rcd_v2x_date = tuf.rcd_v2x_date,
            lot_id = LEFT(tuf.lot_id, 30),
            triwall = LEFT(tuf.triwall, 30),
            lsc_on_hand_date = tuf.lsc_on_hand_date,
            arr_lsc_egypt = tuf.arr_lsc_egypt,
            milstrip_req_no = LEFT(tuf.milstrip_req_no, 25),
            comments = tuf.comments,
            updated_by = current_setting('myapp.user_id')::INT,
            updated_at = NOW(),
            update_source = tuf.update_source,
            status_id = tuf.new_status_id
        FROM temp_updated_fulfillments tuf
        WHERE fi.fulfillment_item_id = tuf.fulfillment_item_id;

        -- Get the number of updated rows
        GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
        RAISE NOTICE 'Updated % fulfillment records.', v_updated_rows;

        -- Increment success count
        v_success_count := v_success_count + v_updated_rows;

        -- Insert audit trail entries for successful updates
        WITH changed_fields AS (
            SELECT
                fi.fulfillment_item_id,
                array_agg(row_to_json(fc)) AS changes,
                tuf.update_source
            FROM fulfillment_items fi
            JOIN temp_updated_fulfillments tuf ON fi.fulfillment_item_id = tuf.fulfillment_item_id
            CROSS JOIN LATERAL (
                VALUES
                    ('shipdoc_tcn', fi.shipdoc_tcn::TEXT, tuf.shipdoc_tcn::TEXT),
                    ('v2x_ship_no', fi.v2x_ship_no::TEXT, tuf.v2x_ship_no::TEXT),
                    ('booking', fi.booking::TEXT, tuf.booking::TEXT),
                    ('vessel', fi.vessel::TEXT, tuf.vessel::TEXT),
                    ('container', fi.container::TEXT, tuf.container::TEXT),
                    ('carrier', fi.carrier::TEXT, tuf.carrier::TEXT),
                    ('sail_date', fi.sail_date::TEXT, tuf.sail_date::TEXT),
                    ('edd_to_ches', fi.edd_to_ches::TEXT, tuf.edd_to_ches::TEXT),
                    ('edd_egypt', fi.edd_egypt::TEXT, tuf.edd_egypt::TEXT),
                    ('rcd_v2x_date', fi.rcd_v2x_date::TEXT, tuf.rcd_v2x_date::TEXT),
                    ('lot_id', fi.lot_id::TEXT, tuf.lot_id::TEXT),
                    ('triwall', fi.triwall::TEXT, tuf.triwall::TEXT),
                    ('lsc_on_hand_date', fi.lsc_on_hand_date::TEXT, tuf.lsc_on_hand_date::TEXT),
                    ('arr_lsc_egypt', fi.arr_lsc_egypt::TEXT, tuf.arr_lsc_egypt::TEXT),
                    ('milstrip_req_no', fi.milstrip_req_no::TEXT, tuf.milstrip_req_no::TEXT),
                    ('comments', fi.comments::TEXT, tuf.comments::TEXT),
                    ('status_id', fi.status_id::TEXT, tuf.new_status_id::TEXT)
            ) AS fc(field, old_value, new_value)
            WHERE fc.old_value IS DISTINCT FROM fc.new_value
            GROUP BY fi.fulfillment_item_id, tuf.update_source
        )
        INSERT INTO audit_trail (
            fulfillment_item_id,
            action,
            changed_by,
            changed_at,
            details,
            update_source,
            role_id,
            user_id
        )
        SELECT
            cf.fulfillment_item_id,
            'UPDATE',
            current_setting('myapp.user_id')::INT,
            NOW(),
            jsonb_build_object('changed_fields', cf.changes),
            cf.update_source,
            current_setting('myapp.role_id')::INT,
            current_setting('myapp.user_id')::INT
        FROM changed_fields cf;

        -- Clean up temporary table for updated fulfillments
        DROP TABLE IF EXISTS temp_updated_fulfillments;

    END LOOP;

    -- After all batches are processed, perform status synchronization for MRL_line_items

    -- Create temporary table to store mrl_status_updates data
    CREATE TEMP TABLE temp_mrl_status_updates ON COMMIT DROP AS
    SELECT
        mli.order_line_item_id,
        MIN(fi.status_id) AS new_status_id
    FROM MRL_line_items mli
    JOIN fulfillment_items fi ON mli.order_line_item_id = fi.order_line_item_id
    GROUP BY mli.order_line_item_id;

    -- Update MRL_line_items using temp_mrl_status_updates
    UPDATE MRL_line_items mli
    SET status_id = mru.new_status_id
    FROM temp_mrl_status_updates mru
    WHERE mli.order_line_item_id = mru.order_line_item_id
      AND mli.status_id IS DISTINCT FROM mru.new_status_id;

    -- Log the number of MRL_line_items updated
    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows > 0 THEN
        RAISE NOTICE 'Updated % MRL_line_items with new status_id based on MIN(status_id).', v_updated_rows;

        -- Insert audit trail entries for MRL_line_items updates
        INSERT INTO audit_trail (
            order_line_item_id,
            action,
            changed_by,
            changed_at,
            details,
            update_source,
            role_id,
            user_id
        )
        SELECT
            mli.order_line_item_id,
            'UPDATE',
            current_setting('myapp.user_id')::INT,
            NOW(),
            jsonb_build_object('changed_fields', jsonb_build_object('status_id', mli.status_id)),
            v_update_source,
            current_setting('myapp.role_id')::INT,
            current_setting('myapp.user_id')::INT
        FROM MRL_line_items mli
        JOIN temp_mrl_status_updates mru ON mli.order_line_item_id = mru.order_line_item_id
        WHERE mli.status_id IS DISTINCT FROM mru.new_status_id;
    ELSE
        RAISE NOTICE 'No MRL_line_items required status updates.';
    END IF;

    -- Clean up temporary table
    DROP TABLE IF EXISTS temp_mrl_status_updates;

    -- Restore the original session_replication_role after bulk updates
    PERFORM set_config('session_replication_role', original_session_replication_role, true);
    RAISE NOTICE 'session_replication_role restored to original value. Triggers are active for individual updates.';

    -- Prepare summary
    summary := jsonb_build_object(
        'status', 'completed',
        'batch_id', v_batch_id,
        'total', v_total_records,
        'success', v_success_count,
        'errors', v_error_count,
        'warnings', v_warning_count,
        'operation', 'update_fulfillment_items_efficient',
        'update_source', v_update_source,
        'timestamp', current_timestamp
    );

EXCEPTION 
    WHEN data_exception THEN
        -- Capture detailed error information
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT,
                                 v_error_detail = PG_EXCEPTION_DETAIL,
                                 v_error_hint = PG_EXCEPTION_HINT,
                                 v_sqlstate = RETURNED_SQLSTATE;

        -- Log the detailed error
        RAISE NOTICE 'Data exception in update_fulfillment_items_efficient: %, Detail: %, Hint: %', 
                    v_error_message, v_error_detail, v_error_hint;

        -- Prepare the summary with detailed error message
        summary := jsonb_build_object(
            'status', 'error',
            'message', 'Data exception occurred: ' || COALESCE(v_error_message, 'No details provided.'),
            'detail', COALESCE(v_error_detail, ''),
            'hint', COALESCE(v_error_hint, ''),
            'operation', 'update_fulfillment_items_efficient',
            'timestamp', current_timestamp
        );
        RETURN; -- Exit after handling exception

    WHEN OTHERS THEN
        -- Capture detailed error information
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT,
                                 v_error_detail = PG_EXCEPTION_DETAIL,
                                 v_error_hint = PG_EXCEPTION_HINT,
                                 v_sqlstate = RETURNED_SQLSTATE;

        -- Restore the original session_replication_role in case of error
        PERFORM set_config('session_replication_role', original_session_replication_role, true);
        -- Drop temporary tables in case of error
        DROP TABLE IF EXISTS temp_fulfillment_updates;
        DROP TABLE IF EXISTS temp_multiple_records;
        DROP TABLE IF EXISTS temp_updated_fulfillments;
        DROP TABLE IF EXISTS temp_mrl_status_updates;
        -- Log the unhandled exception with detailed information
        RAISE LOG 'Unhandled exception in update_fulfillment_items_efficient: %, Detail: %, Hint: %, SQLSTATE: %', 
                 v_error_message, v_error_detail, v_error_hint, v_sqlstate;

        -- Prepare the summary with detailed error message
        summary := jsonb_build_object(
            'status', 'error',
            'message', 'Unhandled exception occurred: ' || COALESCE(v_error_message, 'No details provided.'),
            'detail', COALESCE(v_error_detail, ''),
            'hint', COALESCE(v_error_hint, ''),
            'operation', 'update_fulfillment_items_efficient',
            'timestamp', current_timestamp
        );
        RETURN; -- Exit after handling exception
END;
$$;
