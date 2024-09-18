CREATE OR REPLACE PROCEDURE insert_mrl_line_items_efficient(
    IN batch_data JSONB,
    IN v_update_source TEXT,
    OUT summary JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_record_count INT;
    v_success_count INT;
    v_duplicate_count INT := 0;
    v_created_by INT;
    v_role_id INT;
    original_session_replication_role TEXT;
    v_status_id_not_ordered INT;
BEGIN
    -- Drop temporary tables if they exist
    DROP TABLE IF EXISTS temp_mrl_line_items;
    DROP TABLE IF EXISTS temp_inserted_mrl_items;
    DROP TABLE IF EXISTS temp_fulfillment_items;

    -- Validate batch_data
    IF batch_data IS NULL OR jsonb_typeof(batch_data) != 'array' THEN
        RAISE EXCEPTION 'Invalid batch_data: not a JSON array or is NULL';
    END IF;

    -- Get the current user ID from the session
    v_created_by := current_setting('myapp.user_id', true)::INT;
    IF v_created_by IS NULL THEN
        RAISE EXCEPTION 'User ID not set in session.';
    END IF;

    -- Get the role_id for the current user
    SELECT role_id INTO v_role_id FROM users WHERE user_id = v_created_by;
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Role ID not found for user ID %', v_created_by;
    END IF;

    -- Get the status_id for 'NOT ORDERED'
    SELECT status_id INTO v_status_id_not_ordered FROM statuses WHERE status_name = 'NOT ORDERED';
    IF v_status_id_not_ordered IS NULL THEN
        RAISE EXCEPTION 'Status "NOT ORDERED" not found in statuses table';
    END IF;

    -- Prepare the data for bulk insert
    CREATE TEMP TABLE temp_mrl_line_items (
        jcn TEXT,
        twcode TEXT,
        nomenclature TEXT,
        cog TEXT,
        fsc TEXT,
        niin TEXT,
        part_no TEXT,
        qty INT,
        ui TEXT,
        market_research_up MONEY,
        market_research_ep MONEY,
        availability_identifier INT,
        request_date DATE,
        rdd DATE,
        pri VARCHAR(10),
        swlin VARCHAR(20),
        hull_or_shop VARCHAR(20),
        suggested_source TEXT,
        mfg_cage VARCHAR(20),
        apl VARCHAR(50),
        nha_equipment_system TEXT,
        nha_model TEXT,
        nha_serial TEXT,
        techmanual TEXT,
        dwg_pc TEXT,
        requestor_remarks TEXT,
        created_by INT,
        created_at TIMESTAMPTZ,
        update_source TEXT
    );

    -- Insert data into temp_mrl_line_items
    INSERT INTO temp_mrl_line_items
    SELECT
        ni.jcn, ni.twcode, ni.nomenclature, ni.cog, ni.fsc, ni.niin, ni.part_no, ni.qty, ni.ui,
        ni.market_research_up, ni.market_research_ep, ni.availability_identifier,
        ni.request_date, ni.rdd, ni.pri, ni.swlin, ni.hull_or_shop, ni.suggested_source,
        ni.mfg_cage, ni.apl, ni.nha_equipment_system, ni.nha_model, ni.nha_serial,
        ni.techmanual, ni.dwg_pc, ni.requestor_remarks,
        v_created_by, NOW() AT TIME ZONE 'UTC', v_update_source
    FROM jsonb_to_recordset(batch_data) AS ni(
        jcn TEXT,
        twcode TEXT,
        nomenclature TEXT,
        cog TEXT,
        fsc TEXT,
        niin TEXT,
        part_no TEXT,
        qty INT,
        ui TEXT,
        market_research_up MONEY,
        market_research_ep MONEY,
        availability_identifier INT,
        request_date DATE,
        rdd DATE,
        pri VARCHAR(10),
        swlin VARCHAR(20),
        hull_or_shop VARCHAR(20),
        suggested_source TEXT,
        mfg_cage VARCHAR(20),
        apl VARCHAR(50),
        nha_equipment_system TEXT,
        nha_model TEXT,
        nha_serial TEXT,
        techmanual TEXT,
        dwg_pc TEXT,
        requestor_remarks TEXT
    );

    -- Store the record count
    v_record_count := (SELECT COUNT(*) FROM temp_mrl_line_items);

    -- Disable triggers
    original_session_replication_role := current_setting('session_replication_role');
    PERFORM set_config('session_replication_role', 'replica', true);

    -- Create temporary table to hold inserted order_line_item_ids
    CREATE TEMP TABLE temp_inserted_mrl_items (
        order_line_item_id INT
    );

    -- Perform the bulk insert into MRL_line_items and capture inserted IDs
    WITH inserted_ids AS (
        INSERT INTO MRL_line_items (
            jcn, twcode, nomenclature, cog, fsc, niin, part_no, qty, ui,
            market_research_up, market_research_ep, availability_identifier,
            request_date, rdd, pri, swlin, hull_or_shop, suggested_source,
            mfg_cage, apl, nha_equipment_system, nha_model, nha_serial,
            techmanual, dwg_pc, requestor_remarks,
            created_by, created_at, update_source
        )
        SELECT
            t.jcn, t.twcode, t.nomenclature, t.cog, t.fsc, t.niin, t.part_no, t.qty, t.ui,
            t.market_research_up, t.market_research_ep, t.availability_identifier,
            t.request_date, t.rdd, t.pri, t.swlin, t.hull_or_shop, t.suggested_source,
            t.mfg_cage, t.apl, t.nha_equipment_system, t.nha_model, t.nha_serial,
            t.techmanual, t.dwg_pc, t.requestor_remarks,
            t.created_by, t.created_at, t.update_source
        FROM temp_mrl_line_items t
        ON CONFLICT (jcn, twcode) DO NOTHING
        RETURNING order_line_item_id
    )
    INSERT INTO temp_inserted_mrl_items (order_line_item_id)
    SELECT order_line_item_id FROM inserted_ids;

    -- Update success count
    v_success_count := (SELECT COUNT(*) FROM temp_inserted_mrl_items);
    v_duplicate_count := v_record_count - v_success_count;

    -- Create temporary table to hold inserted fulfillment_item_ids
    CREATE TEMP TABLE temp_fulfillment_items (
        fulfillment_item_id INT,
        order_line_item_id INT
    );

    -- Now insert into fulfillment_items and capture inserted IDs
    WITH inserted_fulfillment_ids AS (
        INSERT INTO fulfillment_items (
            order_line_item_id,
            status_id,
            created_by,
            created_at,
            update_source
        )
        SELECT
            mi.order_line_item_id,
            v_status_id_not_ordered,
            v_created_by,
            NOW() AT TIME ZONE 'UTC',
            v_update_source
        FROM temp_inserted_mrl_items mi
        RETURNING fulfillment_item_id, order_line_item_id
    )
    INSERT INTO temp_fulfillment_items (fulfillment_item_id, order_line_item_id)
    SELECT fulfillment_item_id, order_line_item_id FROM inserted_fulfillment_ids;

    -- Insert into audit_trail for MRL_line_items
    INSERT INTO audit_trail (
        order_line_item_id,
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
        mi.order_line_item_id,
        NULL, -- No fulfillment_item_id at this point
        'INSERT',
        v_created_by,
        NOW() AT TIME ZONE 'UTC',
        'Initial MRL Line Item Record created',
        v_update_source,
        v_role_id,
        v_created_by -- Assuming user_id is same as changed_by
    FROM temp_inserted_mrl_items mi;

    -- Insert into audit_trail for fulfillment_items
    INSERT INTO audit_trail (
        order_line_item_id,
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
        fi.order_line_item_id,
        fi.fulfillment_item_id,
        'INSERT',
        v_created_by,
        NOW() AT TIME ZONE 'UTC',
        'Initial Fulfillment Item Record created',
        v_update_source,
        v_role_id,
        v_created_by -- Assuming user_id is same as changed_by
    FROM temp_fulfillment_items fi;

    -- Restore the original session_replication_role
    PERFORM set_config('session_replication_role', original_session_replication_role, true);

    -- Drop temporary tables to clean up
    DROP TABLE IF EXISTS temp_mrl_line_items;
    DROP TABLE IF EXISTS temp_inserted_mrl_items;
    DROP TABLE IF EXISTS temp_fulfillment_items;

    -- Prepare summary
    summary := jsonb_build_object(
        'status', 'completed',
        'total', v_record_count,
        'success', v_success_count,
        'duplicates', v_duplicate_count,
        'operation', 'insert_mrl_line_items_efficient',
        'timestamp', current_timestamp
    );

EXCEPTION WHEN OTHERS THEN
    -- Restore the original session_replication_role in case of error
    PERFORM set_config('session_replication_role', original_session_replication_role, true);
    -- Drop temporary tables in case of error
    DROP TABLE IF EXISTS temp_mrl_line_items;
    DROP TABLE IF EXISTS temp_inserted_mrl_items;
    DROP TABLE IF EXISTS temp_fulfillment_items;
    -- Handle exceptions
    RAISE LOG 'Unhandled exception in insert_mrl_line_items_efficient: %, SQLSTATE: %', SQLERRM, SQLSTATE;
    summary := jsonb_build_object(
        'status', 'error',
        'message', 'Unhandled exception: ' || SQLERRM,
        'operation', 'insert_mrl_line_items_efficient',
        'timestamp', current_timestamp
    );
END;
$$;
