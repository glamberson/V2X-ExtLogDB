CREATE TABLE staged_egypt_weekly_data (
    staged_id SERIAL PRIMARY KEY,
    preprocessed_id INT,
    raw_data_id INT,
    
    -- Identifier fields
    report_name VARCHAR(255),
    report_date DATE,
    sheet_name VARCHAR(255),
    original_line INT,
    system_identifier_code VARCHAR(50),
    
    -- MRL-related fields
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
    
    -- Fulfillment-related fields
    shipdoc_tcn VARCHAR(30),
    v2x_ship_no VARCHAR(20),
    booking VARCHAR(20),
    vessel VARCHAR(30),
    container VARCHAR(25),
    carrier VARCHAR(50),
    sail_date DATE,
    edd_to_ches DATE,
    edd_egypt DATE,
    rcd_v2x_date DATE,
    lot_id VARCHAR(30),
    triwall VARCHAR(30),
    lsc_on_hand_date DATE,
    arr_lsc_egypt DATE,
    milstrip_req_no VARCHAR(25),
    
    -- Additional fields
    additional_data JSONB,
    overall_quality_score DECIMAL(5,2),
    flags JSONB,
    data_integrity_score DECIMAL(5,2),
    consistency_score DECIMAL(5,2),
    completeness_score DECIMAL(5,2),
    check_details JSONB,
    
    -- Metadata
    mapped_fields TEXT[],
    import_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- Composite unique constraint for record identification
    UNIQUE (report_name, report_date, sheet_name, original_line, system_identifier_code)
);

