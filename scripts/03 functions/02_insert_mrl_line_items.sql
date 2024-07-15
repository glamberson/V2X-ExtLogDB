-- version 0.6.3

-- insert mrl line items (bulk)

CREATE OR REPLACE FUNCTION insert_mrl_line_items(batch_data JSONB)
RETURNS VOID AS $$
DECLARE
    rec RECORD;
    new_order_line_item_id INT;
BEGIN
    FOR rec IN SELECT * FROM jsonb_to_recordset(batch_data) AS (
        jcn VARCHAR(50),
        twcode VARCHAR(50),
        nomenclature TEXT,
        cog VARCHAR(10),
        fsc VARCHAR(10),
        niin VARCHAR(20),
        part_no VARCHAR(50),
        qty INT,
        ui VARCHAR(10),
        market_research_up MONEY,
        market_research_ep MONEY,
        availability_identifier VARCHAR(50),
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
        inquiry_status BOOLEAN DEFAULT FALSE,
        created_by INT,
        update_source TEXT
    )
    LOOP
        INSERT INTO MRL_line_items (
            jcn, twcode, nomenclature, cog, fsc, niin, part_no, qty, ui, 
            market_research_up, market_research_ep, availability_identifier, request_date, rdd, 
            pri, swlin, hull_or_shop, suggested_source, mfg_cage, apl, nha_equipment_system, 
            nha_model, nha_serial, techmanual, dwg_pc, requestor_remarks, inquiry_status, 
            created_by, update_source, created_at
        ) VALUES (
            rec.jcn, rec.twcode, rec.nomenclature, rec.cog, rec.fsc, rec.niin, rec.part_no, 
            rec.qty, rec.ui, rec.market_research_up, rec.market_research_ep, rec.availability_identifier, 
            rec.request_date, rec.rdd, rec.pri, rec.swlin, rec.hull_or_shop, rec.suggested_source, 
            rec.mfg_cage, rec.apl, rec.nha_equipment_system, rec.nha_model, rec.nha_serial, rec.techmanual, 
            rec.dwg_pc, rec.requestor_remarks, rec.inquiry_status, rec.created_by, rec.update_source, 
            CURRENT_TIMESTAMP
        )
        RETURNING order_line_item_id INTO new_order_line_item_id;

        -- Create associated fulfillment record
        PERFORM create_fulfillment_record(new_order_line_item_id, rec.created_by, rec.update_source);

        -- Log in audit trail
        PERFORM log_audit('INSERT', new_order_line_item_id, NULL, rec.created_by, 'Initial batch load');
    END LOOP;
END;
$$ LANGUAGE plpgsql;
