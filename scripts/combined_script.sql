-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\01 initialization\01_create_extensions.sql  
-- version 0.11.14


-- Enable pgcrypto extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE EXTENSION IF NOT EXISTS dblink;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\01 initialization\02_create_roles.sql  
-- Create roles table and predefined roles
-- version 0.7.9

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY, -- Unique identifier for the role
    role_name VARCHAR(100) UNIQUE NOT NULL, -- Name of the role, must be unique
    db_role_name VARCHAR(100)
);


-- Insert predefined roles
INSERT INTO roles (role_name, db_role_name) VALUES
    ('KPPO Admin', 'kppo_admin_user'),
    ('Chesapeake Warehouse', 'logistics_user'),
    ('NAVSUP', 'logistics_user'),
    ('Logistics Service Center (LSC)', 'logistics_user'),
    ('Report Viewer', 'report_viewer_user');

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\01 initialization\03_create_users.sql  
-- version 0.7
-- create users table and initial users with assigned roles


CREATE TABLE users (
    user_id SERIAL PRIMARY KEY, -- Unique identifier for the user
    username VARCHAR(100) UNIQUE NOT NULL, -- Username, must be unique
    password_hash VARCHAR(255) NOT NULL, -- Hashed password for the user
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the user was created
);


-- Insert sample users with hashed passwords and role IDs
INSERT INTO users (username, password_hash, role_id) VALUES
    ('admin', crypt('admin_password', gen_salt('bf')), 1),
    ('chesapeake_user', crypt('chesapeake_password', gen_salt('bf')), 2),
    ('navsup_user', crypt('navsup_password', gen_salt('bf')), 3),
    ('lsc_user', crypt('lsc_password', gen_salt('bf')), 4),
    ('report_viewer', crypt('report_viewer_password', gen_salt('bf')), 5);



 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\01_create_statuses.sql  
-- version 0.5.1


CREATE TABLE statuses (
    status_id SERIAL PRIMARY KEY, -- Unique identifier for the status
    status_name VARCHAR(50) UNIQUE NOT NULL, -- Name of the status, must be unique
    status_value INT NOT NULL -- Numeric value representing the status progression
);



-- Insert predefined statuses with the correct order
INSERT INTO statuses (status_name, status_value) VALUES
    ('NOT ORDERED', 10),
    ('INIT PROCESS', 20),
    ('ON ORDER', 30),
    ('RCD CHES WH', 40),
    ('PROC CHES WH', 50),
    ('READY TO SHIP', 60),
    ('FREIGHT FORWARDER', 70),
    ('EN ROUTE TO EGYPT', 80),
    ('ADMINISTRATIVELY REORDERED', 85),
    ('ARR EGYPT', 90),
    ('CORRECTION', 95),
    ('PARTIALLY RECEIVED', 100),
    ('ON HAND EGYPT', 110);
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\02_availability_events.sql  
-- version 0.7.14.8



CREATE TABLE availability_events (
    availability_event_id SERIAL PRIMARY KEY, -- Unique identifier for the availability event
    availability_identifier INT UNIQUE NOT NULL, -- Internal availability identifier used in CMMS
    availability_name VARCHAR(100) NOT NULL, -- Name of the availability event
    start_date DATE NOT NULL, -- Start date of the availability event
    end_date DATE NOT NULL, -- End date of the availability event
    description TEXT, -- Description of the availability event
    created_by INT REFERENCES users(user_id), -- User who created the availability event
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the availability event was created
);

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\02_create_MRL_line_items.sql  
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
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\03_create_fulfillment_items.sql  

-- version 0.11.12
-- Create fulfillment items table (added MILSTRIP/req field)(added carrier field)

CREATE TABLE fulfillment_items (
    fulfillment_item_id SERIAL PRIMARY KEY,
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE,
    created_by INT REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by INT REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    update_source TEXT,
    status_id INT REFERENCES statuses(status_id),
    shipdoc_tcn VARCHAR(30),
    v2x_ship_no VARCHAR(20),
    booking VARCHAR(20),
    vessel VARCHAR(30),
    container VARCHAR(25),
    carrier VARCHAR(50),
    sail_date DATE,
    edd_to_ches DATE,
    edd_egypt DATE, -- Estimated Delivery Date to Egypt
    rcd_v2x_date DATE,
    lot_id VARCHAR(30), -- Lot ID
    triwall VARCHAR(30), -- Triwall number
    lsc_on_hand_date DATE, -- LSC on-hand date
    arr_lsc_egypt DATE, -- Arrival at LSC Egypt date
    milstrip_req_no VARCHAR(25), -- Requisition or MILSTRIP number
    inquiry_status BOOLEAN DEFAULT FALSE, -- Flag set when review of the fulfillment item is requested
    comments TEXT -- Comments regarding the fulfillment item
);



 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\04_create_audit_trail.sql  
-- version 0.7.14.5


-- Create audit_trail table (added fields)


CREATE TABLE audit_trail (
    audit_id SERIAL PRIMARY KEY, -- Unique identifier for the audit trail entry
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    action VARCHAR(100), -- Action performed (e.g., 'Status Updated')
    changed_by INT REFERENCES users(user_id), -- User ID of the person who performed the action
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the action was performed
    details TEXT, -- Details of the action performed
    update_source TEXT, -- Source of the update
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\05_create_line_item_comments.sql  
-- version 0.6


-- Create comments table (cleanup from previous experiments)


CREATE TABLE line_item_comments (
    comment_id SERIAL PRIMARY KEY, -- Unique identifier for the comment
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    comment TEXT, -- The comment text
    commented_by VARCHAR(100), -- Username of the person who made the comment
    commented_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the comment was made
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\06_create_line_item_inquiry.sql  
-- version 0.6


-- Create inquiry status table (cleanup and added fulfillment reference)

CREATE TABLE line_item_inquiry (
    inquiry_id SERIAL PRIMARY KEY, -- Unique identifier for the inquiry
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    inquiry_status BOOLEAN, -- Inquiry status
    updated_by VARCHAR(100), -- Username of the person who updated the inquiry status
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the inquiry status was updated
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\06_create_user_sessions.sql  
-- version 0.7.2



-- Create user_sessions table
CREATE TABLE user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INT REFERENCES users(user_id),
    role_id INT REFERENCES roles(role_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ
); 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\07_create_function_permissions.sql  
-- Create Function permissions table

-- version 0.7.14.22


CREATE TABLE function_permissions (
    function_name TEXT PRIMARY KEY,
    min_role_id INT DEFAULT 9  -- Default to role 9 (lowest privilege) if not specified
);


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\07_create_user_activity.sql  
-- version 0.6


-- Create user activity table (unifying log activity with one record)

CREATE TABLE user_activity (
    activity_id SERIAL PRIMARY KEY, -- Unique identifier for the activity
    user_id INT REFERENCES users(user_id), -- Foreign key to users table
    login_time TIMESTAMPTZ, -- Timestamp of the login
    logout_time TIMESTAMPTZ, -- Timestamp of the logout
    activity_details TEXT -- Details of the activity performed
);


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\09_temp_bulk_update.sql  
-- version 0.7.4



CREATE TABLE temp_bulk_update (
    fulfillment_item_id SERIAL PRIMARY KEY,
    order_line_item_id INT,
    edd_to_ches DATE,
    rcd_v2x_date DATE,
    lot_id VARCHAR(15),
    triwall VARCHAR(15),
    shipdoc_tcn VARCHAR(30),
    v2x_ship_no VARCHAR(20),
    booking VARCHAR(20),
    vessel VARCHAR(30),
    container VARCHAR(25),
    sail_date DATE,
    edd_to_egypt DATE,
    arr_lsc_egypt DATE,
    lsc_on_hand_date DATE,
    carrier VARCHAR(50),
    milstrip_req_no VARCHAR(25), -- Requisition or MILSTRIP number
    status_id INT REFERENCES statuses(status_id),
    flag_for_review BOOLEAN DEFAULT FALSE,
    comments TEXT,
    reason TEXT
);

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\10_create_failed_logins.sql  
-- version 0.6

-- Create failed logins table


CREATE TABLE failed_logins (
    failed_login_id SERIAL PRIMARY KEY, -- Unique identifier for the failed login attempt
    username VARCHAR(100), -- Username of the person who attempted to log in
    attempt_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp of the failed login attempt
    reason TEXT -- Reason for the failed login attempt
);
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\100_roles_creation.sql  
-- version 0.11.13

-- Create roles and grant permissions

-- Step 1: Create the "login" role with login capability and NOINHERIT
CREATE ROLE "login" WITH LOGIN PASSWORD 'FOTS-Egypt' NOINHERIT;

-- Create other roles without login capability and with NOINHERIT
CREATE ROLE "kppo_admin_user" NOLOGIN NOINHERIT;
CREATE ROLE "logistics_user" NOLOGIN NOINHERIT;
CREATE ROLE "report_viewer_user" NOLOGIN NOINHERIT;

-- Step 2: Set Default Privileges
-- For Tables and Views
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO "report_viewer_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "logistics_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO "kppo_admin_user";

-- For Sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- For Functions (Stored Procedures)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 3: Grant SELECT on the users table to validate credentials
GRANT SELECT ON users TO "login";

-- Step 5: Grant database connection privilege
GRANT CONNECT ON DATABASE "ExtLogDB" TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 6: Grant usage on schema
GRANT USAGE ON SCHEMA public TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 7: Grant the ability to switch roles
GRANT "kppo_admin_user" TO "login";
GRANT "logistics_user" TO "login";
GRANT "report_viewer_user" TO "login";

-- Step 8: Grant specific privileges to each role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "logistics_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "kppo_admin_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "report_viewer_user";

-- Step 9: Grant usage on sequences to roles
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO "kppo_admin_user", "logistics_user", "report_viewer_user";
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\11_create_archived_MRL_line_items.sql  
-- version 0.7.14.9

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
    availability_identifier INT REFERENCES availability_events(availability_identifier),
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

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\12_create_archived_fulfillment_items.sql  
-- version 0.6

-- Create archived fulfillment items table


CREATE TABLE archived_fulfillment_items (
    fulfillment_item_id INT PRIMARY KEY, -- Same as fulfillment_items
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE,
    created_by INT REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by INT REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    update_source TEXT,
    status_id INT REFERENCES statuses(status_id),
    shipdoc_tcn VARCHAR(30),
    v2x_ship_no VARCHAR(20),
    booking VARCHAR(20),
    vessel VARCHAR(30),
    container VARCHAR(25),
    sail_date DATE,
    edd_to_ches DATE,
    rcd_v2x_date DATE,
    lot_id VARCHAR(15),
    triwall VARCHAR(15),
    lsc_on_hand_date DATE,
    arr_lsc_egypt DATE,
    milstrip_req_no VARCHAR(25),
    inquiry_status BOOLEAN DEFAULT FALSE,
    comments TEXT,
    archived_by VARCHAR(100), -- Username of the person who archived the fulfillment item
    archived_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the fulfillment item was archived
    archive_reason TEXT -- Reason for archiving the fulfillment item
);

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\13_create_import_error_log.sql  
-- version 0.9.41
-- create import error log table


-- Create the import_error_log table
CREATE TABLE import_error_log (
    error_id SERIAL PRIMARY KEY,
    batch_id UUID NOT NULL,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('MRL_INSERT', 'FULFILLMENT_UPDATE')),
    source_file_line_number INT,
    jcn TEXT,
    twcode TEXT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    error_type TEXT NOT NULL CHECK (error_type IN ('ERROR', 'WARNING')),
    error_message TEXT,
    record_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by INT REFERENCES users(user_id)
);
-- Add a comment to the table for documentation
COMMENT ON TABLE import_error_log IS 'Stores detailed error and warning information for MRL and fulfillment import operations'; 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\20_create_constraints.sql  
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\20_create_staged_egypt_weekly_data.sql  
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

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\02 schema\30_create_indexes.sql  
-- version 0.11.12


-- Indexes for performance improvement
CREATE INDEX idx_mrl_line_items_jcn ON MRL_line_items(jcn);
CREATE INDEX idx_mrl_line_items_twcode ON MRL_line_items(twcode);
CREATE INDEX idx_fulfillment_items_order_line_item_id ON fulfillment_items(order_line_item_id);

-- Indexes for commonly queried fields in audit trail
CREATE INDEX idx_audit_trail_order_line_item_id ON audit_trail(order_line_item_id);
CREATE INDEX idx_audit_trail_fulfillment_item_id ON audit_trail(fulfillment_item_id);
CREATE INDEX idx_audit_trail_changed_at ON audit_trail(changed_at);


-- Create indices for efficient querying
CREATE INDEX idx_import_error_log_batch_id ON import_error_log(batch_id);
CREATE INDEX idx_import_error_log_operation_type ON import_error_log(operation_type);
CREATE INDEX idx_import_error_log_jcn ON import_error_log(jcn);
CREATE INDEX idx_import_error_log_twcode ON import_error_log(twcode);
CREATE INDEX idx_import_error_log_order_line_item_id ON import_error_log(order_line_item_id);
CREATE INDEX idx_import_error_log_fulfillment_item_id ON import_error_log(fulfillment_item_id);
CREATE INDEX idx_import_error_log_error_type ON import_error_log(error_type);
CREATE INDEX idx_import_error_log_created_at ON import_error_log(created_at);
CREATE INDEX idx_import_error_log_resolved ON import_error_log(resolved);

-- Create a composite index for common query patterns
CREATE INDEX idx_import_error_log_composite ON import_error_log(batch_id, operation_type, error_type);

-- Create a GIN index for efficient querying of the JSONB data
CREATE INDEX idx_import_error_log_record_data ON import_error_log USING GIN (record_data);

-- Additional index for faster queries
CREATE INDEX idx_staged_egypt_weekly_data_report ON staged_egypt_weekly_data(report_name, report_date);


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\01_create_functions-01.sql  
-- version 0.7.4

-- functions included are: audit_fulfillment_update, update_mrl_status, log_inquiry_status_change, add_line_item_comment, 
--                         log_line_item_comment,
--                         view_line_item_history,


CREATE OR REPLACE FUNCTION audit_fulfillment_update()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        details, 
        update_source, 
        changed_at
    )
    VALUES (
        NEW.order_line_item_id, 
        NEW.fulfillment_item_id, 
        'Update', 
        NEW.updated_by, 
        'Fulfillment record updated', 
        NEW.update_source, 
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_mrl_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update MRL line item status based on fulfillment records
    UPDATE MRL_line_items
    SET status_id = (
        SELECT MIN(s.status_value)
        FROM fulfillment_items fi
        JOIN statuses s ON fi.status_id = s.status_id
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    ),
    multiple_fulfillments = (
        SELECT COUNT(*) > 1
        FROM fulfillment_items fi
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    )
    WHERE order_line_item_id = NEW.order_line_item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_inquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Inquiry Status Updated',
        NEW.updated_by,
        'Inquiry Status ',  NEW.inquiry_status,
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.updated_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION add_line_item_comment (
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_comment TEXT,
    p_commented_by VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO line_item_comments (order_line_item_id, fulfillment_item_id, comment, commented_by, commented_at, role_id)
    VALUES (p_order_line_item_id, p_fulfillment_item_id, p_comment, p_commented_by, CURRENT_TIMESTAMP AT TIME ZONE 'UTC', p_role_id);

    -- Update the has_comments field in MRL_line_items or fulfillment_items
    IF p_order_line_item_id IS NOT NULL THEN
        UPDATE MRL_line_items
        SET has_comments = TRUE
        WHERE order_line_item_id = p_order_line_item_id;
    ELSE
        UPDATE fulfillment_items
        SET has_comments = TRUE
        WHERE fulfillment_item_id = p_fulfillment_item_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION log_line_item_comment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Comment Added',
        NEW.commented_by,
        'Comment: ' || NEW.comment,
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.commented_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION view_line_item_history(p_order_line_item_id INT)
RETURNS TABLE (
    action_time TIMESTAMPTZ,
    action VARCHAR,
    changed_by VARCHAR,
    details TEXT,
    role_name VARCHAR,
    comment TEXT,
    comment_by VARCHAR,
    comment_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        at.changed_at AS action_time,
        at.action,
        at.changed_by,
        at.details,
        r.role_name,
        lc.comment,
        lc.commented_by AS comment_by,
        lc.commented_at AS comment_time
    FROM
        audit_trail at
    LEFT JOIN
        line_item_comments lc ON at.order_line_item_id = lc.order_line_item_id
    LEFT JOIN
        roles r ON at.role_id = r.role_id
    WHERE
        at.order_line_item_id = p_order_line_item_id
    ORDER BY
        at.changed_at, lc.commented_at;
END;
$$ LANGUAGE plpgsql;



 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\01_create_functions-02.sql  
-- version 0.6

-- functions included: bulk_update_fulfillment_items,
--                     audit_line_item_update, log_status_change,
--                     update_mrl_status,




-- Function to perform bulk update of fulfillment items
CREATE OR REPLACE FUNCTION bulk_update_fulfillment_items()
RETURNS VOID AS $$
DECLARE
    record RECORD;
BEGIN
    -- Loop through each record in the temp_bulk_update table
    FOR record IN SELECT * FROM temp_bulk_update LOOP
        -- Check if the fulfillment item exists
        IF EXISTS (SELECT 1 FROM fulfillment_items WHERE fulfillment_item_id = record.fulfillment_item_id) THEN
            -- Update the fulfillment item
            PERFORM update_fulfillment_item(
                record.fulfillment_item_id,
                record.order_line_item_id,
                record.milstrip_req_no,
                record.edd_to_ches,
                record.rcd_v2x_date,
                record.lot_id,
                record.triwall,
                record.shipdoc_tcn,
                record.v2x_ship_no,
                record.booking,
                record.vessel,
                record.container,
                record.sail_date,
                record.edd_to_egypt,
                record.arr_lsc_egypt,
                record.lsc_on_hand_date,
                record.carrier,
                record.status_id,
                'Bulk Update',
                record.reason
            );
        ELSE
            -- Flag the record for manual review if the fulfillment item does not exist
            UPDATE temp_bulk_update
            SET flag_for_review = TRUE
            WHERE fulfillment_item_id = record.fulfillment_item_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION audit_line_item_update()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Update',
        NEW.updated_by,
        'Updated record',
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.updated_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION log_status_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Status Updated',
        NEW.updated_by,
        'Status changed to ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id),
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_mrl_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update MRL line item status based on fulfillment records
    UPDATE MRL_line_items
    SET status_id = (
        SELECT MIN(s.status_value)
        FROM fulfillment_items fi
        JOIN statuses s ON fi.status_id = s.status_id
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    ),
    multiple_fulfillments = (
        SELECT COUNT(*) > 1
        FROM fulfillment_items fi
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    )
    WHERE order_line_item_id = NEW.order_line_item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_archive_fulfillment_item.sql  
-- version 0.6

-- archive fulfillment item


CREATE OR REPLACE FUNCTION archive_fulfillment_item(
    p_fulfillment_item_id INT,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Insert the fulfillment item into the archive table
    INSERT INTO archived_fulfillment_items (
        fulfillment_item_id,
        order_line_item_id,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        shipdoc_tcn,
        v2x_ship_no,
        booking,
        vessel,
        container,
        sail_date,
        edd_to_ches,
        rcd_v2x_date,
        lot_id,
        triwall,
        lsc_on_hand_date,
        arr_lsc_egypt,
        milstrip_req_no,
        inquiry_status,
        comments,
        archived_by,
        archived_at,
        archive_reason
    )
    SELECT
        fulfillment_item_id,
        order_line_item_id,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        shipdoc_tcn,
        v2x_ship_no,
        booking,
        vessel,
        container,
        sail_date,
        edd_to_ches,
        rcd_v2x_date,
        lot_id,
        triwall,
        lsc_on_hand_date,
        arr_lsc_egypt,
        milstrip_req_no,
        inquiry_status,
        comments,
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason
    FROM fulfillment_items
    WHERE fulfillment_item_id = p_fulfillment_item_id;

    -- Delete the fulfillment item from the original table
    DELETE FROM fulfillment_items
    WHERE fulfillment_item_id = p_fulfillment_item_id;

    -- Insert into audit trail
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
    VALUES (
        (SELECT order_line_item_id FROM fulfillment_items WHERE fulfillment_item_id = p_fulfillment_item_id),
        p_fulfillment_item_id,
        'Fulfillment Item Archived',
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Archive Operation',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_archive_line_item.sql  
-- version 0.6.2

-- archive line item

CREATE OR REPLACE FUNCTION archive_line_item(
    p_order_line_item_id INT,
    p_jcn VARCHAR,
    p_twcode VARCHAR,
    p_nomenclature TEXT,
    p_cog VARCHAR,
    p_fsc VARCHAR,
    p_niin VARCHAR,
    p_part_no VARCHAR,
    p_qty INT,
    p_ui VARCHAR,
    p_market_research_up MONEY,
    p_market_research_ep MONEY,
    p_avail_typ VARCHAR,
    p_request_date DATE,
    p_rdd DATE,
    p_pri VARCHAR,
    p_swlin VARCHAR,
    p_hull_or_shop VARCHAR,
    p_suggested_source TEXT,
    p_mfg_cage VARCHAR,
    p_apl VARCHAR,
    p_nha_equipment_system TEXT,
    p_nha_model TEXT,
    p_nha_serial TEXT,
    p_techmanual TEXT,
    p_dwg_pc TEXT,
    p_requestor_remarks TEXT,
    p_inquiry_status BOOLEAN,
    p_created_by INT,
    p_created_at TIMESTAMPTZ,
    p_updated_by INT,
    p_updated_at TIMESTAMPTZ,
    p_update_source TEXT,
    p_status_id INT,
    p_received_quantity INT,
    p_has_comments BOOLEAN,
    p_multiple_fulfillments BOOLEAN,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Insert the line item into the archive table
    INSERT INTO archived_MRL_line_items (
        order_line_item_id,
        jcn,
        twcode,
        nomenclature,
        cog,
        fsc,
        niin,
        part_no,
        qty,
        ui,
        market_research_up,
        market_research_ep,
        avail_typ,
        request_date,
        rdd,
        pri,
        swlin,
        hull_or_shop,
        suggested_source,
        mfg_cage,
        apl,
        nha_equipment_system,
        nha_model,
        nha_serial,
        techmanual,
        dwg_pc,
        requestor_remarks,
        inquiry_status,
        created_by,
        created_at,
        updated_by,
        updated_at,
        update_source,
        status_id,
        received_quantity,
        has_comments,
        multiple_fulfillments,
        archived_by,
        archived_at,
        archive_reason
    )
    SELECT
        p_order_line_item_id,
        p_jcn,
        p_twcode,
        p_nomenclature,
        p_cog,
        p_fsc,
        p_niin,
        p_part_no,
        p_qty,
        p_ui,
        p_market_research_up,
        p_market_research_ep,
        p_avail_typ,
        p_request_date,
        p_rdd,
        p_pri,
        p_swlin,
        p_hull_or_shop,
        p_suggested_source,
        p_mfg_cage,
        p_apl,
        p_nha_equipment_system,
        p_nha_model,
        p_nha_serial,
        p_techmanual,
        p_dwg_pc,
        p_requestor_remarks,
        p_inquiry_status,
        p_created_by,
        p_created_at,
        p_updated_by,
        p_updated_at,
        p_update_source,
        p_status_id,
        p_received_quantity,
        p_has_comments,
        p_multiple_fulfillments,
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason
    FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;

    -- Delete the line item from the original table
    DELETE FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;

    -- Insert into audit trail
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
    VALUES (
        p_order_line_item_id,
        'Line Item Archived',
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Archive Operation',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_cascade_status_to_mrl.sql  
-- version 0.6.3

-- cascade_status_to_mrl


CREATE OR REPLACE FUNCTION cascade_status_to_mrl(order_line_item_id INT)
RETURNS VOID AS $$
DECLARE
    new_status_id INT;
BEGIN
    SELECT MIN(status_id) INTO new_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = order_line_item_id;

    UPDATE MRL_line_items
    SET status_id = new_status_id, updated_at = CURRENT_TIMESTAMP
    WHERE order_line_item_id = order_line_item_id;

    -- Log status change in audit trail
    PERFORM log_audit('UPDATE', order_line_item_id, NULL, current_setting('user.id')::INT, 'MRL status updated based on fulfillment');
END;
$$ LANGUAGE plpgsql;



 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_combined_status_audit_update.sql  
-- version 0.7


CREATE OR REPLACE FUNCTION combined_status_audit_update()
RETURNS TRIGGER AS $$
DECLARE
    v_status_id INT;
BEGIN
    -- Handle MRL line item insert
    IF (TG_OP = 'INSERT' AND TG_TABLE_NAME = 'MRL_line_items') THEN
        INSERT INTO fulfillment_items (order_line_item_id, created_by, status_id)
        VALUES (NEW.order_line_item_id, NEW.created_by, NEW.status_id);
    END IF;

    -- Handle fulfillment item status update
    IF TG_TABLE_NAME = 'fulfillment_items' THEN
        IF NEW.lsc_on_hand_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON HAND EGYPT');
        ELSIF NEW.arr_lsc_egypt IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ARR EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'EN ROUTE TO EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'FREIGHT FORWARDER');
        ELSIF NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'READY TO SHIP');
        ELSIF NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'PROC CHES WH');
        ELSIF NEW.rcd_v2x_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'RCD CHES WH');
        ELSIF NEW.edd_to_ches IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON ORDER');
        ELSIF NEW.milstrip_req_no IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'INIT PROCESS');
        ELSE
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'NOT ORDERED');
        END IF;
    END IF;

    -- Update MRL line item status based on fulfillment status
    SELECT MAX(status_id) INTO v_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;

    UPDATE MRL_line_items
    SET status_id = v_status_id
    WHERE order_line_item_id = NEW.order_line_item_id;

    -- Insert into audit trail
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
    VALUES (
        NEW.order_line_item_id, 
        NEW.fulfillment_item_id, 
        'Status Updated', 
        NEW.updated_by, 
        CURRENT_TIMESTAMP, 
        'Status: ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id), 
        NEW.update_source, 
        NEW.role_id, 
        NEW.user_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_compare_and_update_line_items.sql  
-- version 0.6

-- compare and update line items function


CREATE OR REPLACE FUNCTION compare_and_update_line_items(
    p_temp_table_name TEXT
)
RETURNS VOID AS $$
DECLARE
    r RECORD;
    v_status_id INT;
BEGIN
    FOR r IN EXECUTE 'SELECT * FROM ' || p_temp_table_name LOOP
        -- Check if the order_line_item_id exists in MRL_line_items
        IF EXISTS (SELECT 1 FROM MRL_line_items WHERE order_line_item_id = r.order_line_item_id) THEN
            -- Update existing line item
            UPDATE MRL_line_items
            SET jcn = r.jcn,
                twcode = r.twcode,
                nomenclature = r.nomenclature,
                cog = r.cog,
                fsc = r.fsc,
                niin = r.niin,
                part_no = r.part_no,
                qty = r.qty,
                ui = r.ui,
                market_research_up = r.market_research_up,
                market_research_ep = r.market_research_ep,
                availability_identifier = r.availability_identifier,
                request_date = r.request_date,
                rdd = r.rdd,
                pri = r.pri,
                swlin = r.swlin,
                hull_or_shop = r.hull_or_shop,
                suggested_source = r.suggested_source,
                mfg_cage = r.mfg_cage,
                apl = r.apl,
                nha_equipment_system = r.nha_equipment_system,
                nha_model = r.nha_model,
                nha_serial = r.nha_serial,
                techmanual = r.techmanual,
                dwg_pc = r.dwg_pc,
                requestor_remarks = r.requestor_remarks,
                inquiry_status = r.inquiry_status,
                updated_by = r.updated_by,
                updated_at = CURRENT_TIMESTAMP,
                update_source = r.update_source
            WHERE order_line_item_id = r.order_line_item_id;

            -- Update fulfillment status
            v_status_id := (SELECT status_id FROM statuses WHERE status_name = r.status_name);
            PERFORM update_fulfillment_status(
                r.order_line_item_id,
                r.fulfillment_item_id,
                v_status_id,
                r.updated_by,
                r.update_source,
                r.role_id,
                r.user_id
            );
        ELSE
            -- Insert new line item
            INSERT INTO MRL_line_items (
                order_line_item_id,
                jcn,
                twcode,
                nomenclature,
                cog,
                fsc,
                niin,
                part_no,
                qty,
                ui,
                market_research_up,
                market_research_ep,
                availability_identifier,
                request_date,
                rdd,
                pri,
                swlin,
                hull_or_shop,
                suggested_source,
                mfg_cage,
                apl,
                nha_equipment_system,
                nha_model,
                nha_serial,
                techmanual,
                dwg_pc,
                requestor_remarks,
                inquiry_status,
                created_by,
                created_at,
                updated_by,
                updated_at,
                update_source
            ) VALUES (
                r.order_line_item_id,
                r.jcn,
                r.twcode,
                r.nomenclature,
                r.cog,
                r.fsc,
                r.niin,
                r.part_no,
                r.qty,
                r.ui,
                r.market_research_up,
                r.market_research_ep,
                r.availability_identifier,
                r.request_date,
                r.rdd,
                r.pri,
                r.swlin,
                r.hull_or_shop,
                r.suggested_source,
                r.mfg_cage,
                r.apl,
                r.nha_equipment_system,
                r.nha_model,
                r.nha_serial,
                r.techmanual,
                r.dwg_pc,
                r.requestor_remarks,
                r.inquiry_status,
                r.created_by,
                CURRENT_TIMESTAMP,
                r.updated_by,
                CURRENT_TIMESTAMP,
                r.update_source
            );

            -- Insert initial fulfillment item
            INSERT INTO fulfillment_items (
                order_line_item_id,
                created_by,
                status_id
            ) VALUES (
                r.order_line_item_id,
                r.created_by,
                (SELECT status_id FROM statuses WHERE status_name = r.status_name)
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_create_fulfillment_record.sql  
-- version 0.8.10


-- First, let's ensure the create_fulfillment_record function is up to date
CREATE OR REPLACE FUNCTION create_fulfillment_record(
    p_order_line_item_id INT, 
    p_created_by INT, 
    p_update_source TEXT
)
RETURNS VOID AS $$
DECLARE
    v_status_id INT;
BEGIN
    -- Get the 'NOT ORDERED' status ID
    SELECT status_id INTO v_status_id FROM statuses WHERE status_name = 'NOT ORDERED';

    INSERT INTO fulfillment_items (
        order_line_item_id, 
        created_by, 
        update_source, 
        created_at,
        status_id
    )
    VALUES (
        p_order_line_item_id, 
        p_created_by, 
        p_update_source, 
        CURRENT_TIMESTAMP,
        v_status_id
    );

    -- Log in audit trail
    PERFORM log_audit('INSERT', p_order_line_item_id, NULL, 'Fulfillment record created', p_update_source);
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_log_all_changes.sql  
-- version 0.6


CREATE OR REPLACE FUNCTION log_all_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert log for updates
    IF TG_OP = 'UPDATE' THEN
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
        VALUES (
            NEW.order_line_item_id,
            NEW.fulfillment_item_id,
            'UPDATE',
            COALESCE(NEW.updated_by, OLD.updated_by),
            CURRENT_TIMESTAMP,
            'Updated Fields: ' || hstore(OLD.*) - hstore(NEW.*),
            NEW.update_source,
            COALESCE(NEW.role_id, OLD.role_id),
            COALESCE(NEW.user_id, OLD.user_id)
        );
    END IF;

    -- Insert log for inserts
    IF TG_OP = 'INSERT' THEN
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
        VALUES (
            NEW.order_line_item_id,
            NEW.fulfillment_item_id,
            'INSERT',
            NEW.updated_by,
            CURRENT_TIMESTAMP,
            'New Record Created',
            NEW.update_source,
            NEW.role_id,
            NEW.user_id
        );
    END IF;

    -- Insert log for deletes
    IF TG_OP = 'DELETE' THEN
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
        VALUES (
            OLD.order_line_item_id,
            OLD.fulfillment_item_id,
            'DELETE',
            OLD.updated_by,
            CURRENT_TIMESTAMP,
            'Record Deleted',
            OLD.update_source,
            OLD.role_id,
            OLD.user_id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_log_audit.sql  
-- version 0.7.14.39 Adding more detailed logging and error handling

CREATE OR REPLACE FUNCTION log_audit(
    action TEXT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    details TEXT,
    update_source TEXT
)
RETURNS VOID AS $$
DECLARE
    current_user_id INT;
    current_role_id INT;
BEGIN
    RAISE LOG 'log_audit function started';
    
    -- Detailed input logging
    RAISE LOG 'log_audit input: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 action, order_line_item_id, fulfillment_item_id, details, update_source;

    -- Retrieve and log session variables
    BEGIN
        current_user_id := current_setting('myapp.user_id', true)::INT;
        current_role_id := current_setting('myapp.role_id', true)::INT;
        RAISE LOG 'Session variables retrieved: user_id=%, role_id=%', current_user_id, current_role_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Error retrieving session variables: %', SQLERRM;
        current_user_id := NULL;
        current_role_id := NULL;
    END;

    -- Detailed type checking
    RAISE LOG 'Data types: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 pg_typeof(action), pg_typeof(order_line_item_id), pg_typeof(fulfillment_item_id), 
                 pg_typeof(details), pg_typeof(update_source);

    -- Attempt to insert into audit_trail with detailed error handling
    BEGIN
        RAISE LOG 'Attempting to insert into audit_trail';
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
        ) VALUES (
            order_line_item_id,
            fulfillment_item_id,
            action,
            current_user_id,
            CURRENT_TIMESTAMP,
            details,
            update_source,
            current_role_id,
            current_user_id
        );
        RAISE LOG 'Successfully inserted into audit_trail';
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Error inserting into audit_trail: %, SQLSTATE: %', SQLERRM, SQLSTATE;
        RAISE LOG 'Problematic data: order_line_item_id=%, fulfillment_item_id=%, action=%, changed_by=%, details=%, update_source=%, role_id=%, user_id=%',
                     order_line_item_id, fulfillment_item_id, action, current_user_id, details, update_source, current_role_id, current_user_id;
    END;
    
    RAISE LOG 'log_audit function completed';
END;
$$ LANGUAGE plpgsql;




 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_log_failed_login_attempt.sql  
-- version 0.6


CREATE OR REPLACE FUNCTION log_failed_login_attempt(
    p_username VARCHAR,
    p_reason TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO failed_logins (
        username,
        attempt_time,
        reason
    )
    VALUES (
        p_username,
        CURRENT_TIMESTAMP,
        p_reason
    );
END;
$$ LANGUAGE plpgsql;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_log_user_activity.sql  
-- version 0.7.6.2


CREATE OR REPLACE FUNCTION log_user_activity(
    p_user_id INT,
    p_login_time TIMESTAMPTZ,
    p_logout_time TIMESTAMPTZ,
    p_activity_details TEXT
)
RETURNS VOID AS $$
DECLARE
    v_activity_id INT;
BEGIN
    IF p_login_time IS NOT NULL THEN
        -- This is a login activity, insert a new record
        INSERT INTO user_activity (
            user_id,
            login_time,
            logout_time,
            activity_details
        )
        VALUES (
            p_user_id,
            p_login_time,
            p_logout_time,
            p_activity_details
        );
    ELSE
        -- This is a logout activity, update the existing record
        -- First, find the most recent login without a logout
        SELECT activity_id INTO v_activity_id
        FROM user_activity
        WHERE user_id = p_user_id
          AND logout_time IS NULL
        ORDER BY login_time DESC
        LIMIT 1;

        IF FOUND THEN
            -- Update the found record
            UPDATE user_activity
            SET logout_time = p_logout_time,
                activity_details = COALESCE(activity_details, '') || '; ' || p_activity_details
            WHERE activity_id = v_activity_id;
        ELSE
            -- If no record was found, insert a new record
            INSERT INTO user_activity (
                user_id,
                login_time,
                logout_time,
                activity_details
            )
            VALUES (
                p_user_id,
                CURRENT_TIMESTAMP, -- Assume login time is now as a fallback
                p_logout_time,
                'Logout without matching login; ' || p_activity_details
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql; 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_update_fulfillment_and_mrl_status.sql  
-- version 0.10.22
-- Updated Trigger Function to Set MRL_line_items.status_id to MIN(status_id)

CREATE OR REPLACE FUNCTION update_fulfillment_and_mrl_status()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status_id INT;
    v_new_status_id INT;
    v_status_name TEXT;
    v_mrl_status_id INT;
    v_mrl_old_status_id INT;
BEGIN
    -- Logging the trigger invocation
    RAISE LOG 'Trigger fired for fulfillment_item_id: %, order_line_item_id: %', NEW.fulfillment_item_id, NEW.order_line_item_id;
    
    -- Store the old status
    v_old_status_id := OLD.status_id;
    RAISE LOG 'Old fulfillment_item status_id: %', v_old_status_id;

    -- Determine the new status based on the updated fulfillment item using CASE for clarity
    SELECT status_id INTO v_new_status_id
    FROM statuses
    WHERE status_name = CASE
        WHEN NEW.lsc_on_hand_date IS NOT NULL THEN 'ON HAND EGYPT'
        WHEN NEW.arr_lsc_egypt IS NOT NULL THEN 'ARR EGYPT'
        WHEN NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN 'EN ROUTE TO EGYPT'
        WHEN NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN 'FREIGHT FORWARDER'
        WHEN NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN 'READY TO SHIP'
        WHEN NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN 'PROC CHES WH'
        WHEN NEW.rcd_v2x_date IS NOT NULL THEN 'RCD CHES WH'
        WHEN NEW.edd_to_ches IS NOT NULL THEN 'ON ORDER'
        WHEN NEW.milstrip_req_no IS NOT NULL THEN 'INIT PROCESS'
        ELSE 'NOT ORDERED'
    END;

    RAISE LOG 'Determined new fulfillment_item status_id: %', v_new_status_id;

    -- Update the fulfillment item status if it has changed
    IF v_new_status_id != v_old_status_id THEN
        NEW.status_id := v_new_status_id;
        RAISE LOG 'Updating fulfillment item status from % to %', v_old_status_id, v_new_status_id;
        
        -- Get the status name for logging
        SELECT status_name INTO v_status_name FROM statuses WHERE status_id = v_new_status_id;
        RAISE LOG 'New fulfillment_item status name: %', v_status_name;

        -- Log the status change for the fulfillment item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NEW.fulfillment_item_id,
            format(
                'Fulfillment item status updated from %s to %s', 
                (SELECT status_name FROM statuses WHERE status_id = v_old_status_id),
                v_status_name
            ),
            NEW.update_source
        );
    ELSE
        RAISE LOG 'Fulfillment item status not changed. Remains at status_id: %', v_old_status_id;
    END IF;

    -- Update the associated MRL line item status to the MIN(status_id) among related fulfillment_items
    SELECT status_id INTO v_mrl_old_status_id
    FROM MRL_line_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    RAISE LOG 'Current MRL_line_item status_id: %', v_mrl_old_status_id;

    -- Determine the new MRL_line_item status_id as the MIN of associated fulfillment_items.status_id
    SELECT MIN(fi.status_id) INTO v_mrl_status_id
    FROM fulfillment_items fi
    WHERE fi.order_line_item_id = NEW.order_line_item_id;

    RAISE LOG 'Determined new MRL_line_item status_id: %', v_mrl_status_id;

    -- Update MRL_line_items.status_id if it has changed
    IF v_mrl_status_id != v_mrl_old_status_id THEN
        UPDATE MRL_line_items
        SET status_id = v_mrl_status_id
        WHERE order_line_item_id = NEW.order_line_item_id;
        RAISE LOG 'Updated MRL_line_item status_id from % to %', v_mrl_old_status_id, v_mrl_status_id;

        -- Get the new status name for logging
        SELECT status_name INTO v_status_name FROM statuses WHERE status_id = v_mrl_status_id;
        RAISE LOG 'New MRL_line_item status name: %', v_status_name;

        -- Log the status change for the MRL line item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NULL, -- fulfillment_item_id is not applicable here
            format(
                'MRL line item status updated from %s to %s', 
                (SELECT status_name FROM statuses WHERE status_id = v_mrl_old_status_id),
                v_status_name
            ),
            NEW.update_source
        );
    ELSE
        RAISE LOG 'MRL_line_item status not changed. Remains at status_id: %', v_mrl_old_status_id;
    END IF;

    RAISE LOG 'Trigger function completed for fulfillment_item_id: %', NEW.fulfillment_item_id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in trigger function for fulfillment_item_id %: %', NEW.fulfillment_item_id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_update_fulfillment_status.sql  
-- version 0.6.5

-- update fulfillment status

CREATE OR REPLACE FUNCTION update_fulfillment_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lsc_on_hand_date IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON HAND EGYPT');
    ELSIF NEW.arr_lsc_egypt IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ARR EGYPT');
    ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'EN ROUTE TO EGYPT');
    ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'FREIGHT FORWARDER');
    ELSIF NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'READY TO SHIP');
    ELSIF NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'PROC CHES WH');
    ELSIF NEW.rcd_v2x_date IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'RCD CHES WH');
    ELSIF NEW.edd_to_ches IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON ORDER');
    ELSIF NEW.milstrip_req_no IS NOT NULL THEN
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'INIT PROCESS');
    ELSE
        NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'NOT ORDERED');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_update_fulfillment_status-simple.sql-notused  
-- version 0.6.5_simple

-- Function to Update Fulfillment Status

CREATE OR REPLACE FUNCTION update_fulfillment_status(order_line_item_id INT, fulfillment_item_id INT, status_id INT, updated_by INT, update_source TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE fulfillment_items
    SET status_id = status_id, updated_by = updated_by, update_source = update_source, updated_at = CURRENT_TIMESTAMP
    WHERE fulfillment_item_id = fulfillment_item_id;

    -- Log status change in audit trail
    PERFORM log_audit('UPDATE', order_line_item_id, fulfillment_item_id, updated_by, 'Fulfillment status updated');

    -- Cascade status to MRL line item
    PERFORM cascade_status_to_mrl(order_line_item_id);
END;
$$ LANGUAGE plpgsql;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_update_inquiry_status_with_reason.sql  
-- version 0.6


-- function to update inquiry status with reason (added fields, cleaned up)


CREATE OR REPLACE FUNCTION update_inquiry_status_with_reason(
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_inquiry_status BOOLEAN,
    p_updated_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    UPDATE line_item_inquiry
    SET inquiry_status = p_inquiry_status,
        updated_by = p_updated_by,
        updated_at = CURRENT_TIMESTAMP,
        role_id = p_role_id,
        user_id = p_user_id
    WHERE order_line_item_id = p_order_line_item_id
    AND fulfillment_item_id = p_fulfillment_item_id;

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
    VALUES (
        p_order_line_item_id,
        p_fulfillment_item_id,
        'Inquiry Status Updated',
        p_updated_by,
        CURRENT_TIMESTAMP,
        p_reason,
        'Inquiry Update',
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_view_inquiry_status_items.sql  
-- version 0.6


CREATE OR REPLACE FUNCTION view_inquiry_status_items()
RETURNS TABLE (
    order_line_item_id INT,
    fulfillment_item_id INT,
    inquiry_status BOOLEAN,
    updated_by VARCHAR,
    updated_at TIMESTAMPTZ,
    role_id INT,
    user_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        order_line_item_id,
        fulfillment_item_id,
        inquiry_status,
        updated_by,
        updated_at,
        role_id,
        user_id
    FROM line_item_inquiry
    WHERE inquiry_status = TRUE;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\02_view_line_item_history_with_comments.sql  
-- version 0.6

-- view line item history with comments


CREATE OR REPLACE FUNCTION view_line_item_history_with_comments(
    p_order_line_item_id INT
)
RETURNS TABLE (
    audit_id INT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    action VARCHAR,
    changed_by VARCHAR,
    changed_at TIMESTAMPTZ,
    details TEXT,
    update_source TEXT,
    role_id INT,
    user_id INT,
    comment_id INT,
    comment TEXT,
    commented_by VARCHAR,
    commented_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.audit_id,
        a.order_line_item_id,
        a.fulfillment_item_id,
        a.action,
        a.changed_by,
        a.changed_at,
        a.details,
        a.update_source,
        a.role_id,
        a.user_id,
        c.comment_id,
        c.comment,
        c.commented_by,
        c.commented_at
    FROM 
        audit_trail a
    LEFT JOIN 
        line_item_comments c
    ON 
        a.order_line_item_id = c.order_line_item_id
    WHERE 
        a.order_line_item_id = p_order_line_item_id;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\03_user_login.sql  

-- version 0.7.14.39

CREATE OR REPLACE FUNCTION user_login(
    p_username VARCHAR,
    p_password VARCHAR,
    p_duration INTERVAL
)
RETURNS TABLE (session_id UUID, login_user_id INT, login_role_id INT) AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
    v_password_hash VARCHAR;
    v_session_id UUID;
BEGIN
    -- Check if the user exists and get the password hash
    SELECT user_id, role_id, password_hash INTO v_user_id, v_role_id, v_password_hash
    FROM users
    WHERE username = p_username;

    -- Verify the password
    IF FOUND AND crypt(p_password, v_password_hash) = v_password_hash THEN
        -- Create a session
        v_session_id := create_session(v_user_id, v_role_id, p_duration);

        -- Set session variables
        PERFORM set_session_variables(v_session_id, v_user_id, v_role_id);

        -- Log the login activity
        PERFORM log_user_activity(v_user_id, CURRENT_TIMESTAMP, NULL, 'User logged in');

        RETURN QUERY SELECT v_session_id, v_user_id, v_role_id;
    ELSE
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'Incorrect password');

        RETURN QUERY SELECT NULL::UUID, NULL::INT, NULL::INT;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'User not found');

        RETURN QUERY SELECT NULL::UUID, NULL::INT, NULL::INT;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\03_user_logout.sql  

-- version 0.7.6.1



CREATE OR REPLACE FUNCTION user_logout(
    p_session_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
BEGIN
    -- Get user information from the session
    SELECT user_id, role_id INTO v_user_id, v_role_id
    FROM user_sessions
    WHERE session_id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired session';
    END IF;

    -- Log the logout activity
    PERFORM log_user_activity(v_user_id, NULL, CURRENT_TIMESTAMP, 'User logged out');

    -- Invalidate the session
    PERFORM invalidate_session(p_session_id);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\04_fulfillment_bulk_update.sql  
-- version 0.7.4


-- process bulk update (fulfillment)


CREATE OR REPLACE FUNCTION process_bulk_update()
RETURNS VOID AS $$
BEGIN
    -- Update fulfillment items based on temp_bulk_update data
    UPDATE fulfillment_items fi
    SET 
        fi.shipdoc_tcn = tbu.shipdoc_tcn,
        fi.v2x_ship_no = tbu.v2x_ship_no,
        fi.booking = tbu.booking,
        fi.vessel = tbu.vessel,
        fi.container = tbu.container,
        fi.carrier = tbu.carrier,
        fi.sail_date = tbu.sail_date,
        fi.edd_to_ches = tbu.edd_to_ches,
        fi.rcd_v2x_date = tbu.rcd_v2x_date,
        fi.lot_id = tbu.lot_id,
        fi.triwall = tbu.triwall,
        fi.lsc_on_hand_date = tbu.lsc_on_hand_date,
        fi.arr_lsc_egypt = tbu.arr_lsc_egypt,
        fi.milstrip_req_no = tbu.milstrip_req_no,
        fi.updated_at = NOW(),
        fi.updated_by = 'bulk_update',
        fi.update_source = tbu.update_source,
        fi.comments = tbu.comments
    FROM temp_bulk_update tbu
    WHERE 
        tbu.order_line_item_id = fi.order_line_item_id 
        AND tbu.fulfillment_item_id = fi.fulfillment_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        details, 
        update_source, 
        changed_at
    )
    SELECT 
        tbu.order_line_item_id, 
        tbu.fulfillment_item_id, 
        'Bulk Update', 
        'admin_user', 
        tbu.reason, 
        tbu.update_source, 
        NOW()
    FROM temp_bulk_update tbu;

    -- Flag records with multiple fulfillment items
    UPDATE temp_bulk_update tbu
    SET flag_for_review = TRUE
    WHERE (
        SELECT COUNT(*) 
        FROM fulfillment_items fi 
        WHERE fi.order_line_item_id = tbu.order_line_item_id
    ) > 1;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\04_login_wrapper.sql  

-- version 0.7.14.39

CREATE OR REPLACE FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL)
RETURNS TABLE (session_id UUID, login_user_id INT, login_role_id INT, login_db_role_name VARCHAR)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_user_id INT;
    v_role_id INT;
    v_db_role_name VARCHAR;
BEGIN
    -- Call user_login function
    SELECT * INTO v_session_id, v_user_id, v_role_id 
    FROM user_login(p_username, p_password, p_duration);

    -- If login was successful
    IF v_session_id IS NOT NULL THEN
        -- Get the database role name
        SELECT r.db_role_name INTO v_db_role_name
        FROM roles r
        WHERE r.role_id = v_role_id;
    END IF;

    RETURN QUERY SELECT v_session_id, v_user_id, v_role_id, v_db_role_name;
END;
$$; 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\04_set_user_role.sql  

-- version 0.7.14.39

CREATE OR REPLACE FUNCTION set_user_role(p_db_role_name VARCHAR)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_db_role_name IS NOT NULL THEN
        EXECUTE 'SET ROLE ' || quote_ident(p_db_role_name);
    END IF;
END;
$$;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\04_update_fulfillment_item.sql  
-- version 0.7.4


CREATE OR REPLACE FUNCTION update_fulfillment_item(
    p_fulfillment_item_id INT,
    p_field_name VARCHAR,
    p_new_value TEXT,
    p_updated_by VARCHAR,
    p_update_source VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Construct dynamic SQL to update the specified field
    EXECUTE 'UPDATE fulfillment_items SET ' || p_field_name || ' = $1, updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE fulfillment_item_id = $3'
    USING p_new_value, p_updated_by, p_fulfillment_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        (SELECT order_line_item_id FROM fulfillment_items WHERE fulfillment_item_id = p_fulfillment_item_id),
        'Update',
        p_updated_by,
        'Updated ' || p_field_name || ' to ' || p_new_value,
        p_role_id,
        (SELECT user_id FROM users WHERE username = p_updated_by)
    );
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\04_update_mrl_item.sql  
-- version 0.7.4



CREATE OR REPLACE FUNCTION update_mrl_line_item(
    p_order_line_item_id INT,
    p_field_name VARCHAR,
    p_new_value TEXT,
    p_updated_by VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Construct dynamic SQL to update the specified field
    EXECUTE 'UPDATE MRL_line_items SET ' || p_field_name || ' = $1 WHERE order_line_item_id = $2'
    USING p_new_value, p_order_line_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        p_order_line_item_id,
        'Update',
        p_updated_by,
        'Updated ' || p_field_name || ' to ' || p_new_value,
        p_role_id,
        (SELECT user_id FROM users WHERE username = p_updated_by)
    );
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_create_session.sql  
-- version 0.7.14.28

-- Function to create a session
CREATE OR REPLACE FUNCTION create_session(p_user_id INT, p_role_id INT, p_duration INTERVAL)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
BEGIN
    INSERT INTO user_sessions (user_id, role_id, expires_at)
    VALUES (p_user_id, p_role_id, CURRENT_TIMESTAMP + p_duration)
    RETURNING session_id INTO v_session_id;

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_invalidate_session.sql  
-- version 0.7.14.28

-- Function to invalidate a session
CREATE OR REPLACE FUNCTION invalidate_session(p_session_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_sessions
    WHERE session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_renew_session.sql  
-- renew_session function
-- version 0.8.23

CREATE OR REPLACE FUNCTION renew_session(
    p_session_id UUID,
    p_duration INTERVAL
)
RETURNS BOOLEAN AS $$
DECLARE
    rows_updated INT;
BEGIN
    RAISE LOG 'Attempting to renew session: session_id = %, duration = %', p_session_id, p_duration;

    UPDATE user_sessions
    SET expires_at = NOW() + p_duration
    WHERE session_id = p_session_id
    AND expires_at > NOW(); -- Ensure we only renew active sessions

    GET DIAGNOSTICS rows_updated = ROW_COUNT;

    IF rows_updated > 0 THEN
        RAISE LOG 'Session renewed successfully: session_id %, new expires_at %', p_session_id, NOW() + p_duration;
        RETURN TRUE;
    ELSE
        RAISE LOG 'Session not renewed: session_id %, duration %, expired or not found.', p_session_id, p_duration;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_set_session_variables.sql  
-- version 0.7.14.17

CREATE OR REPLACE FUNCTION set_session_variables(p_session_id UUID, p_user_id INT, p_role_id INT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('myapp.session_id', p_session_id::TEXT, FALSE);
    PERFORM set_config('myapp.user_id', p_user_id::TEXT, FALSE);
    PERFORM set_config('myapp.role_id', p_role_id::TEXT, FALSE);
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_validate_session.sql  
-- version 0.7.14.29

CREATE OR REPLACE FUNCTION validate_session(p_session_id UUID)
RETURNS TABLE (
    session_user_id INT,
    session_role_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT user_id AS session_user_id, role_id AS session_role_id
    FROM user_sessions
    WHERE session_id = p_session_id AND expires_at > CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\05_validate_session_and_permission.sql  
-- validate session and permission (version checking new function permissions table)

-- version 0.8.07

CREATE OR REPLACE FUNCTION validate_session_and_permission(
    p_session_id UUID,
    p_function_name TEXT
) RETURNS TABLE (
    is_valid BOOLEAN,
    session_user_id INT,
    session_role_id INT
) AS $$
DECLARE
    vs RECORD;
    fp RECORD;
BEGIN
    -- Get the minimum role_id required for the function
    SELECT INTO fp min_role_id
    FROM function_permissions
    WHERE function_name = p_function_name
    UNION ALL
    SELECT 9  -- Default to role 9 if function not found in table
    LIMIT 1;

    -- Validate the session
    SELECT INTO vs *
    FROM validate_session(p_session_id);

    -- Determine if the session is valid and has sufficient permissions
    is_valid := vs.session_user_id IS NOT NULL AND vs.session_role_id <= fp.min_role_id;
    session_user_id := vs.session_user_id;
    session_role_id := vs.session_role_id;

    -- Renew the session if valid
    IF is_valid THEN
        BEGIN
            PERFORM renew_session(p_session_id, '1 hour');
        EXCEPTION WHEN OTHERS THEN
            RAISE LOG 'Error renewing session: %', SQLERRM;
        END;
    END IF;

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\06_trigger_create_fulfillment_record.sql  
-- version 0.8.10

CREATE OR REPLACE FUNCTION trigger_create_fulfillment_record()
RETURNS TRIGGER AS $$
BEGIN
    -- Here you can add any additional logic, error handling, or checks specific to the trigger
    IF NEW.order_line_item_id IS NULL THEN
        RAISE EXCEPTION 'Cannot create fulfillment record: order_line_item_id is NULL';
    END IF;

    PERFORM create_fulfillment_record(
        NEW.order_line_item_id, 
        NEW.created_by, 
        COALESCE(NEW.update_source, 'Initial MRL creation')
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise
        RAISE NOTICE 'Error in trigger_create_fulfillment_record: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\03 functions\99_trigger_code.sql  
-- version 0.9.39


CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION trigger_create_fulfillment_record();


-- Create the trigger on the fulfillment_items table
CREATE TRIGGER trg_update_fulfillment_and_mrl_status
BEFORE UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION update_fulfillment_and_mrl_status();

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\04 data\001_more_roles_creation.sql  
-- version 0.9.10

-- Create roles and grant permissions


-- Step 4: Grant EXECUTE on necessary functions to the "login" role
GRANT EXECUTE ON FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION create_session(user_id INT, role_id INT, duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION log_user_activity(user_id INT, login_time TIMESTAMPTZ, logout_time TIMESTAMPTZ, activity TEXT) TO "login";
GRANT EXECUTE ON FUNCTION log_failed_login_attempt(username VARCHAR, reason TEXT) TO "login";
GRANT EXECUTE ON FUNCTION set_user_role(p_db_role_name VARCHAR) TO "login";


-- Step 11: Specifically for the audit_trail table's sequence
GRANT USAGE, SELECT ON SEQUENCE audit_trail_audit_id_seq TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 12: For MRL_line_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE mrl_line_items_order_line_item_id_seq TO "kppo_admin_user", "logistics_user";

-- Step 13: For fulfillment_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE fulfillment_items_fulfillment_item_id_seq TO "kppo_admin_user", "logistics_user";
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\04 data\01_insert_initial_data.sql  
-- version 0.8.62


INSERT INTO availability_events (availability_identifier, availability_name, start_date, end_date, description, created_by)
VALUES ('41', 'Sadeeq', '2024-01-01', '202-01-02', 'This is a dummy description', 1);
INSERT INTO availability_events (availability_identifier, availability_name, start_date, end_date, description, created_by)
VALUES ('66', 'Alexandria', '2024-03-01', '2024-11-11', 'This is a dummy description also', 1);





INSERT INTO function_permissions (function_name, min_role_id)
VALUES ('insert_mrl_line_items', 1);





 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\05 utilities\01_create_views.sql  
-- version 0.7


CREATE OR REPLACE VIEW availability_events_view AS
SELECT 
    ae.availability_event_id,
    ae.availability_name,
    ae.start_date,
    ae.end_date,
    ae.description,
    ae.created_at,
    u.username AS created_by
FROM 
    availability_events ae
JOIN 
    users u ON ae.created_by = u.user_id;


CREATE OR REPLACE VIEW line_item_inquiry_view AS
SELECT 
    li.inquiry_id,
    li.order_line_item_id,
    m.jcn,
    m.twcode,
    li.inquiry_status,
    li.updated_by,
    li.updated_at,
    r.role_name
FROM 
    line_item_inquiry li
JOIN 
    MRL_line_items m ON li.order_line_item_id = m.order_line_item_id
JOIN 
    roles r ON li.role_id = r.role_id;


CREATE OR REPLACE VIEW inquiry_status_items_view AS
SELECT 
    m.order_line_item_id,
    m.jcn,
    m.twcode,
    m.nomenclature,
    m.cog,
    m.fsc,
    m.niin,
    m.part_no,
    m.qty,
    m.ui,
    m.market_research_up,
    m.market_research_ep,
    m.availability_identifier, -- Updated field name
    m.request_date,
    m.rdd,
    m.pri,
    m.swlin,
    m.hull_or_shop,
    m.suggested_source,
    m.mfg_cage,
    m.apl,
    m.nha_equipment_system,
    m.nha_model,
    m.nha_serial,
    m.techmanual,
    m.dwg_pc,
    m.requestor_remarks,
    m.inquiry_status,
    m.created_by,
    m.created_at,
    m.status_id,
    m.received_quantity,
    m.has_comments,
    m.multiple_fulfillments, -- Updated field name
    li.inquiry_status AS current_inquiry_status,
    li.updated_by AS inquiry_updated_by,
    li.updated_at AS inquiry_updated_at
FROM 
    MRL_line_items m
JOIN 
    line_item_inquiry li ON m.order_line_item_id = li.order_line_item_id
WHERE 
    li.inquiry_status = TRUE
ORDER BY 
    li.updated_at DESC;


-- View to show all line items with their current status
CREATE OR REPLACE VIEW line_items_with_status_view AS
SELECT 
    l.order_line_item_id,
    l.jcn,
    l.twcode,
    l.nomenclature,
    l.cog,
    l.fsc,
    l.niin,
    l.part_no,
    l.qty,
    l.ui,
    l.market_research_up,
    l.market_research_ep,
    l.availability_identifier,
    l.request_date,
    l.rdd,
    l.pri,
    l.swlin,
    l.hull_or_shop,
    l.suggested_source,
    l.mfg_cage,
    l.apl,
    l.nha_equipment_system,
    l.nha_model,
    l.nha_serial,
    l.techmanual,
    l.dwg_pc,
    l.requestor_remarks,
    l.inquiry_status,
    l.created_by,
    l.created_at,
    s.status_name AS current_status,
    l.received_quantity,
    l.has_comments,
    l.multiple_fulfillments
FROM MRL_line_items l
JOIN statuses s ON l.status_id = s.status_id;


CREATE OR REPLACE VIEW combined_line_items_fulfillments_view AS
SELECT
    m.order_line_item_id,
    m.jcn,
    m.twcode,
    m.nomenclature,
    m.cog,
    m.fsc,
    m.niin,
    m.part_no,
    m.qty,
    m.ui,
    m.market_research_up,
    m.market_research_ep,
    m.availability_identifier,
    m.request_date,
    m.rdd,
    m.pri,
    m.swlin,
    m.hull_or_shop,
    m.suggested_source,
    m.mfg_cage,
    m.apl,
    m.nha_equipment_system,
    m.nha_model,
    m.nha_serial,
    m.techmanual,
    m.dwg_pc,
    m.requestor_remarks,
    m.inquiry_status,
    m.created_by AS mrl_created_by,
    m.created_at AS mrl_created_at,
    m.updated_by AS mrl_updated_by,
    m.updated_at AS mrl_updated_at,
    m.update_source AS mrl_update_source,
    m.status_id AS mrl_status_id,
    m.received_quantity,
    m.has_comments,
    m.multiple_fulfillments,
    f.fulfillment_item_id,
    f.created_by AS fulfillment_created_by,
    f.created_at AS fulfillment_created_at,
    f.updated_by AS fulfillment_updated_by,
    f.updated_at AS fulfillment_updated_at,
    f.update_source AS fulfillment_update_source,
    f.status_id AS fulfillment_status_id,
    f.shipdoc_tcn,
    f.v2x_ship_no,
    f.booking,
    f.vessel,
    f.container,
    f.sail_date,
    f.edd_to_ches,
    f.rcd_v2x_date,
    f.lot_id,
    f.triwall,
    f.lsc_on_hand_date,
    f.arr_lsc_egypt,
    f.milstrip_req_no,
    f.inquiry_status AS fulfillment_inquiry_status,
    f.comments AS fulfillment_comments
FROM
    MRL_line_items m
LEFT JOIN
    fulfillment_items f
ON
    m.order_line_item_id = f.order_line_item_id;


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\05 utilities\01_debug table (procedure call log).sql  
-- Create a table to log procedure invocations
CREATE TABLE procedure_call_log (
    id SERIAL PRIMARY KEY,
    procedure_name TEXT,
    call_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\05 utilities\02_create_search_views.sql  
-- version 0.9.24		Doc

-- Creat Combined line items fulfillments for Search View


CREATE OR REPLACE VIEW combined_line_items_fulfillments_Search_view AS
SELECT
    m.order_line_item_id,
    m.jcn,
    m.twcode,
    m.nomenclature,
    m.cog,
    m.fsc,
    m.niin,
    m.part_no,
    m.qty,
    m.ui,
    m.market_research_up,
    m.market_research_ep,
    m.availability_identifier,
    m.request_date,
    m.rdd,
    m.pri,
    m.swlin,
    m.hull_or_shop,
    m.suggested_source,
    m.mfg_cage,
    m.apl,
    m.nha_equipment_system,
    m.nha_model,
    m.nha_serial,
    m.techmanual,
    m.dwg_pc
FROM
    MRL_line_items m
LEFT JOIN
    fulfillment_items f
ON
    m.order_line_item_id = f.order_line_item_id;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\05 utilities\100_link_databases.sql  



CREATE SERVER reportsdb_server
FOREIGN DATA WRAPPER dblink_fdw
OPTIONS (host 'localhost', dbname 'ReportsDB');


CREATE USER MAPPING FOR CURRENT_USER
SERVER reportsdb_server
OPTIONS (user 'postgres', password '123456');


 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\06 procedures\01_create_procedures.sql  
-- version 0.5.1



CREATE OR REPLACE PROCEDURE batch_update_statuses(updates JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    update_item JSONB; -- Variable to hold each update item from the JSONB array
    record_id INT; -- Variable to hold the order_line_item_id from the update item
    new_status VARCHAR; -- Variable to hold the new status_name from the update item
BEGIN
    -- Loop through each item in the updates JSONB array
    FOR update_item IN SELECT * FROM jsonb_array_elements(updates)
    LOOP
        -- Extract the order_line_item_id and status_name from the update item
        record_id := (update_item->>'order_line_item_id')::INT;
        new_status := update_item->>'status_name';
        
        -- Update the status_id of the fulfillment item based on the new status_name
        UPDATE fulfillment_items
        SET status_id = (SELECT status_id FROM statuses WHERE status_name = new_status)
        WHERE order_line_item_id = record_id;

        -- Perform the MRL status update to reflect the changes
        PERFORM update_mrl_status();
    END LOOP;
END;
$$;

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\06 procedures\02_insert_mrl_line_items.sql  
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

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\06 procedures\02_insert_mrl_line_items_efficient.sql  
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
 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\06 procedures\03_update_fulfillment_items.sql  
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

 
 
-- Including C:\Users\vse\Desktop\External Logistics Database\ExtLogisticsDB Github Repository\V2X-ExtLogDB\scripts\06 procedures\03_update_fulfillment_items_efficient.sql  
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
 
 
