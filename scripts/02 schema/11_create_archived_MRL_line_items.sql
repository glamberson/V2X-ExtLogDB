-- version 0.6

-- Create archived MRL line items table

CREATE TABLE archived_MRL_line_items (
    order_line_item_id INT PRIMARY KEY, -- Same as MRL_line_items
    jcn VARCHAR(50) NOT NULL,
    twcode VARCHAR(50) NOT NULL,
    nomenclature TEXT,
    cog VARCHAR(10),
    fsc VARCHAR(10),
    niin VARCHAR(20),
    part_no VARCHAR(50),
    qty INT,
    ui VARCHAR(10),
    market_research_up MONEY,
    market_research_ep MONEY,
    availability_identifier VARCHAR(50) REFERENCES availability_events(availability_identifier),
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
    created_by INT REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by INT REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    update_source TEXT,
    status_id INT REFERENCES statuses(status_id),
    received_quantity INT DEFAULT 0,
    has_comments BOOLEAN DEFAULT FALSE,
    multiple_fulfillments BOOLEAN DEFAULT FALSE,
    archived_by VARCHAR(100), -- Username of the person who archived the line item
    archived_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the line item was archived
    archive_reason TEXT -- Reason for archiving the line item
);

