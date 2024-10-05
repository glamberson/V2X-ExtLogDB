 -- version 0.7.14.9


-- Create MRL line items table ("updated" fields added)


-- Create MRL_line_items table
CREATE TABLE MRL_line_items (
    order_line_item_id SERIAL PRIMARY KEY, -- Internal unique identifier for the MRL line item record, not published or used externally
    jcn VARCHAR(50) NOT NULL, -- Job Control Number, unique identifier for work orders, old IMDS, or manually generated orders
    twcode VARCHAR(50) NOT NULL, -- Technical Writer Code, combined with JCN for unique identification
    nomenclature TEXT, -- Noun description of material being ordered
    cog VARCHAR(10), -- Cognizance Symbol, two-position prefix for supply management information
    fsc VARCHAR(10), -- Federal Supply Classification, four-digit code for supply items
    niin VARCHAR(20), -- NATO Item Identification Number, last 9 digits of NSN, unique to the item
    part_no VARCHAR(50), -- Part number of the item
    qty INT, -- Quantity of the item to be ordered
    ui VARCHAR(10), -- Unit of Issue (Unit of Measure), determines the measuring unit for the material
    market_research_up MONEY, -- Unit price in USD determined by market research (Haystack GOLD or historical info)
    market_research_ep MONEY, -- Total estimated price in USD (unit price  quantity), based on market research
    availability_identifier INT REFERENCES availability_events(availability_identifier), -- Internal availability identifier used in CMMS
    request_date DATE, -- Date when the LSC submits the line item for fulfillmentprocurement
    rdd DATE, -- Required Delivery Date, the date by which an item must be received in Egypt
    pri VARCHAR(10), -- Priority level set for the procurement of the item
    swlin VARCHAR(20), -- Secondary Work Line Item Number
    hull_or_shop VARCHAR(20), -- Specifies whether the item is designated for a ship (hull) or a shop
    suggested_source TEXT, -- Recommended vendor and contactshipping information
    mfg_cage VARCHAR(20), -- Manufacturer CAGE Code, unique identifier for manufacturerssuppliers
    apl VARCHAR(50), -- Allowance Parts List, authorized list of parts for maintenance and repair
    nha_equipment_system TEXT, -- Equipment system associated with the NHA
    nha_model TEXT, -- Model of the NHA
    nha_serial TEXT, -- Serial number of the NHA
    techmanual TEXT, -- Technical manual where the specified material is referenced (e.g., JFMM, NSTM)
    dwg_pc TEXT, -- DrawingIllustration reference in the technical manual where the item is specified
    requestor_remarks TEXT, -- Notes added by KPPO Material Manager for processing or clarification
    inquiry_status BOOLEAN DEFAULT FALSE, -- Flag set when review of the line item is requested
    created_by INT REFERENCES users(user_id), -- User who created the line item in this database
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the line item was created
    updated_by INT REFERENCES users(user_id), -- User who last updated the line item
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the line item was last updated
    update_source TEXT, -- Source of the update
    status_id INT REFERENCES statuses(status_id), -- Foreign key to statuses table
    received_quantity INT DEFAULT 0, -- Tracks the number of units received, useful for multiple fulfillment records
    has_comments BOOLEAN DEFAULT FALSE, -- Indicates if any user comments have been added for the line item
    multiple_fulfillments BOOLEAN DEFAULT FALSE, -- Indicates if the line item has more than one fulfillment record
    UNIQUE (jcn, twcode) -- Ensures unique combination of JCN and TWCODE
);
