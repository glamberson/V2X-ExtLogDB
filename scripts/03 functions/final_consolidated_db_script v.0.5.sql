CREATE OR REPLACE FUNCTION combined_status_audit_update()
RETURNS TRIGGER AS $$
DECLARE
    v_status_id INT;
BEGIN
    IF (TG_OP = 'INSERT' AND TG_TABLE_NAME = 'MRL_line_items') THEN
        INSERT INTO fulfillment_items (order_line_item_id, created_by, status_id)
        VALUES (NEW.order_line_item_id, NEW.created_by, NEW.status_id);
    END IF;
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
    SELECT MAX(status_id) INTO v_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    UPDATE MRL_line_items
    SET status_id = v_status_id
    WHERE order_line_item_id = NEW.order_line_item_id;
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
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();
CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();
CREATE OR REPLACE FUNCTION user_login(
    p_username VARCHAR,
    p_password VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
    v_password_hash VARCHAR;
    v_login_successful BOOLEAN := FALSE;
BEGIN
    SELECT user_id, role_id, password_hash INTO v_user_id, v_role_id, v_password_hash
    FROM users
    WHERE username = p_username;
    IF crypt(p_password, v_password_hash) = v_password_hash THEN
        v_login_successful := TRUE;
        PERFORM log_user_activity(v_user_id, 'login', 'User logged in');
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'login',
            p_username,
            'User logged in',
            v_role_id,
            v_user_id
        );
    ELSE
        PERFORM log_failed_login_attempt\(p_username, 'Incorrect password');
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'Incorrect password',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );
    END IF;
    RETURN v_login_successful;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        PERFORM log_failed_login_attempt\(p_username, 'User not found');
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'User not found',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION user_logout(
    p_user_id INT
)
RETURNS VOID AS $$
DECLARE
    v_username VARCHAR;
    v_role_id INT;
BEGIN
    SELECT username, role_id INTO v_username, v_role_id
    FROM users
    WHERE user_id = p_user_id;
    PERFORM log_user_activity(p_user_id, 'logout', 'User logged out');
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NULL, -- No specific line item ID for general user activity
        'logout',
        v_username,
        'User logged out',
        v_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY, -- Unique identifier for the role
    role_name VARCHAR(100) UNIQUE NOT NULL -- Name of the role, must be unique
);
INSERT INTO roles (role_name) VALUES
    ('KPPO Admin'),
    ('Chesapeake Warehouse'),
    ('NAVSUP'),
    ('Logistics Service Center (LSC)'),
    ('Report Viewer');
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY, -- Unique identifier for the user
    username VARCHAR(100) UNIQUE NOT NULL, -- Username, must be unique
    password_hash VARCHAR(255) NOT NULL, -- Hashed password for the user
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the user was created
);
INSERT INTO users (username, password_hash, role_id) VALUES
    ('admin', crypt('admin_password', gen_salt('bf')), 1),
    ('chesapeake_user', crypt('chesapeake_password', gen_salt('bf')), 2),
    ('navsup_user', crypt('navsup_password', gen_salt('bf')), 3),
    ('lsc_user', crypt('lsc_password', gen_salt('bf')), 4),
    ('report_viewer', crypt('viewer_password', gen_salt('bf')), 5);
CREATE TABLE statuses (
    status_id SERIAL PRIMARY KEY, -- Unique identifier for the status
    status_name VARCHAR(50) UNIQUE NOT NULL, -- Name of the status, must be unique
    status_value INT NOT NULL -- Numeric value representing the status progression
);
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
CREATE TABLE availability_events (
    availability_event_id SERIAL PRIMARY KEY, -- Unique identifier for the availability event
    availability_identifier VARCHAR(50) UNIQUE NOT NULL, -- Internal availability identifier used in CMMS
    availability_name VARCHAR(100) NOT NULL, -- Name of the availability event
    start_date DATE NOT NULL, -- Start date of the availability event
    end_date DATE NOT NULL, -- End date of the availability event
    description TEXT, -- Description of the availability event
    created_by INT REFERENCES users(user_id), -- User who created the availability event
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the availability event was created
);
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
    availability_identifier VARCHAR(50) REFERENCES availability_events(availability_identifier), -- Internal availability identifier used in CMMS
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
CREATE TABLE fulfillment_items (
    fulfillment_item_id SERIAL PRIMARY KEY, -- Unique identifier for the fulfillment item
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    created_by INT REFERENCES users(user_id), -- User who created the fulfillment item
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the fulfillment item was created
    updated_by INT REFERENCES users(user_id), -- User who last updated the fulfillment item
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the fulfillment item was last updated
    update_source TEXT, -- Source of the update
    status_id INT REFERENCES statuses(status_id), -- Foreign key to statuses table
    shipdoc_tcn VARCHAR(30), -- Shipment document or transportation control number
    v2x_ship_no VARCHAR(20), -- V2X shipment number
    booking VARCHAR(20), -- Booking number
    vessel VARCHAR(30), -- Vessel name
    container VARCHAR(25), -- Container number
    sail_date DATE, -- Sail date
    edd_to_ches DATE, -- Estimated delivery date to Chesapeake warehouse
    rcd_v2x_date DATE, -- Received by V2X date
    lot_id VARCHAR(15), -- Lot ID
    triwall VARCHAR(15), -- Triwall number
    lsc_on_hand_date DATE, -- LSC on-hand date
    arr_lsc_egypt DATE, -- Arrival at LSC Egypt date
    milstrip_req_no VARCHAR(25), -- Requisition or MILSTRIP number
    inquiry_status BOOLEAN DEFAULT FALSE, -- Flag set when review of the fulfillment item is requested
    comments TEXT -- Comments regarding the fulfillment item
);
CREATE TABLE audit_trail (
    audit_id SERIAL PRIMARY KEY, -- Unique identifier for the audit trail entry
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    action VARCHAR(100), -- Action performed (e.g., 'Status Updated')
    changed_by VARCHAR(100), -- Username of the person who performed the action
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the action was performed
    details TEXT, -- Details of the action performed
    update_source TEXT, -- Source of the update
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);
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
CREATE TABLE user_activity (
    activity_id SERIAL PRIMARY KEY, -- Unique identifier for the activity
    user_id INT REFERENCES users(user_id), -- Foreign key to users table
    login_time TIMESTAMPTZ, -- Timestamp of the login
    logout_time TIMESTAMPTZ, -- Timestamp of the logout
    activity_details TEXT -- Details of the activity performed
);
CREATE TABLE failed_logins (
    failed_login_id SERIAL PRIMARY KEY, -- Unique identifier for the failed login attempt
    username VARCHAR(100), -- Username of the person who attempted to log in
    attempt_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp of the failed login attempt
    reason TEXT -- Reason for the failed login attempt
);
CREATE OR REPLACE FUNCTION combined_status_audit_update()
RETURNS TRIGGER AS $$
DECLARE
    new_order_line_item_id INT;
    v_status_id INT;
    v_updated_by INTEGER;
    v_update_source TEXT;
    v_role_id INT;
    v_user_id INT;
BEGIN
    SELECT role_id INTO v_role_id FROM roles WHERE role_name = 'KPPO Admin';
    SELECT user_id INTO v_user_id FROM users WHERE username = 'postgres';
    v_updated_by := COALESCE(NEW.updated_by, NEW.created_by, v_user_id);
    v_update_source := COALESCE(NEW.update_source, 'Initial Creation');
    IF (TG_OP = 'INSERT' AND TG_TABLE_NAME = 'mrl_line_items') THEN
        INSERT INTO fulfillment_items (order_line_item_id, created_by, status_id)
        VALUES (NEW.order_line_item_id, v_updated_by, NEW.status_id);
    END IF;
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
    SELECT MAX(status_id) INTO v_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    UPDATE MRL_line_items
    SET status_id = v_status_id
    WHERE order_line_item_id = NEW.order_line_item_id;
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
        v_updated_by, 
        CURRENT_TIMESTAMP, 
        'Status: ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id), 
        v_update_source, 
        v_role_id, 
        v_updated_by
    );
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
        NEW.order_line_item_id, 
        'MRL Status Updated', 
        v_updated_by, 
        CURRENT_TIMESTAMP, 
        'MRL Status: ' || (SELECT status_name FROM statuses WHERE status_id = v_status_id), 
        v_update_source, 
        v_role_id, 
        v_updated_by
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_combined_status_audit_update ON fulfillment_items;
DROP TRIGGER IF EXISTS trg_create_fulfillment_on_mrl_insert ON MRL_line_items;
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();
CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();
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
CREATE OR REPLACE FUNCTION log_user_activity(
    p_user_id INT,
    p_login_time TIMESTAMPTZ,
    p_logout_time TIMESTAMPTZ,
    p_activity_details TEXT
)
RETURNS VOID AS $$
BEGIN
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
END;
$$ LANGUAGE plpgsql;
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
CREATE OR REPLACE FUNCTION update_fulfillment_status(
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_status_id INT,
    p_updated_by VARCHAR,
    p_update_source TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
    UPDATE fulfillment_items
    SET status_id = p_status_id,
        updated_by = p_updated_by,
        updated_at = CURRENT_TIMESTAMP,
        update_source = p_update_source
    WHERE fulfillment_item_id = p_fulfillment_item_id;
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
        'Fulfillment Status Updated',
        p_updated_by,
        CURRENT_TIMESTAMP,
        'Status ID: ' || p_status_id,
        p_update_source,
        p_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION compare_and_update_line_items(
    p_temp_table_name TEXT
)
RETURNS VOID AS $$
DECLARE
    r RECORD;
    v_status_id INT;
BEGIN
    FOR r IN EXECUTE 'SELECT * FROM ' || p_temp_table_name LOOP
        IF EXISTS (SELECT 1 FROM MRL_line_items WHERE order_line_item_id = r.order_line_item_id) THEN
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
CREATE OR REPLACE FUNCTION log_user_activity(
    p_user_id INT,
    p_login_time TIMESTAMPTZ,
    p_logout_time TIMESTAMPTZ,
    p_activity_details TEXT
)
RETURNS VOID AS $$
BEGIN
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
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION log_user_login()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_activity (
        user_id,
        login_time,
        activity_details
    )
    VALUES (
        NEW.user_id,
        CURRENT_TIMESTAMP,
        'User logged in'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_log_user_login
AFTER INSERT ON user_activity
FOR EACH ROW
EXECUTE FUNCTION log_user_login();
CREATE OR REPLACE FUNCTION log_user_logout()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE user_activity
    SET logout_time = CURRENT_TIMESTAMP,
        activity_details = activity_details || '; User logged out'
    WHERE user_id = NEW.user_id
    AND logout_time IS NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_log_user_logout
AFTER UPDATE ON user_activity
FOR EACH ROW
EXECUTE FUNCTION log_user_logout();
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
CREATE OR REPLACE FUNCTION archive_line_item(
    p_order_line_item_id INT,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
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
        update_source,
        status_id,
        received_quantity,
        has_comments,
        multiple_fulfillments,
        p_archived_by,
        CURRENT_TIMESTAMP,
        p_reason
    FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;
    DELETE FROM MRL_line_items
    WHERE order_line_item_id = p_order_line_item_id;
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
CREATE OR REPLACE FUNCTION archive_fulfillment_item(
    p_fulfillment_item_id INT,
    p_archived_by VARCHAR,
    p_reason TEXT,
    p_role_id INT,
    p_user_id INT
)
RETURNS VOID AS $$
BEGIN
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
    DELETE FROM fulfillment_items
    WHERE fulfillment_item_id = p_fulfillment_item_id;
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
CREATE OR REPLACE FUNCTION trg_archive_line_item()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM archive_line_item(
        NEW.order_line_item_id,
        NEW.archived_by,
        NEW.archive_reason,
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_archive_line_item
AFTER UPDATE OF archived_by ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION trg_archive_line_item();
CREATE OR REPLACE FUNCTION trg_archive_fulfillment_item()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM archive_fulfillment_item(
        NEW.fulfillment_item_id,
        NEW.archived_by,
        NEW.archive_reason,
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_archive_fulfillment_item
AFTER UPDATE OF archived_by ON fulfillment_items
FOR EACH ROW
WHEN (NEW.archived_by IS NOT NULL)
EXECUTE FUNCTION trg_archive_fulfillment_item();
CREATE OR REPLACE VIEW combined_line_items_fulfillments AS
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
CREATE OR REPLACE FUNCTION log_all_changes()
RETURNS TRIGGER AS $$
BEGIN
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
CREATE TRIGGER trg_log_all_changes_mrl
AFTER INSERT OR UPDATE OR DELETE ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();
CREATE TRIGGER trg_log_all_changes_fulfillment
AFTER INSERT OR UPDATE OR DELETE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();
CREATE ROLE kppo_admin_user WITH LOGIN PASSWORD 'admin_password';
GRANT ALL PRIVILEGES ON DATABASE "Beta_002" TO kppo_admin_user;
CREATE ROLE readonly_user WITH LOGIN PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE "Beta_002" TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
GRANT INSERT, UPDATE ON TABLE fulfillment_items TO readonly_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
CREATE ROLE report_viewer_user WITH LOGIN PASSWORD 'report_password';
GRANT CONNECT ON DATABASE "Beta_002" TO report_viewer_user;
GRANT USAGE ON SCHEMA public TO report_viewer_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO report_viewer_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO report_viewer_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO report_viewer_user;
GRANT ALL PRIVILEGES ON DATABASE "Beta_002" TO kppo_admin_user;
GRANT CONNECT ON DATABASE "Beta_002" TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
GRANT INSERT, UPDATE ON TABLE fulfillment_items TO readonly_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
GRANT CONNECT ON DATABASE "Beta_002" TO report_viewer_user;
GRANT USAGE ON SCHEMA public TO report_viewer_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO report_viewer_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO report_viewer_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO report_viewer_user;
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

-- Triggers for the combined function
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

CREATE OR REPLACE FUNCTION user_login(
    p_username VARCHAR,
    p_password VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
    v_password_hash VARCHAR;
    v_login_successful BOOLEAN := FALSE;
BEGIN
    -- Check if the user exists and get the password hash
    SELECT user_id, role_id, password_hash INTO v_user_id, v_role_id, v_password_hash
    FROM users
    WHERE username = p_username;

    -- Verify the password
    IF crypt(p_password, v_password_hash) = v_password_hash THEN
        v_login_successful := TRUE;

        -- Log the login activity
        PERFORM log_user_activity(v_user_id, 'login', 'User logged in');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'login',
            p_username,
            'User logged in',
            v_role_id,
            v_user_id
        );
    ELSE
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'Incorrect password');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'Incorrect password',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );
    END IF;

    RETURN v_login_successful;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'User not found');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'User not found',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );

        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION user_logout(
    p_user_id INT
)
RETURNS VOID AS $$
DECLARE
    v_username VARCHAR;
    v_role_id INT;
BEGIN
    -- Get the username and role ID
    SELECT username, role_id INTO v_username, v_role_id
    FROM users
    WHERE user_id = p_user_id;

    -- Log the logout activity
    PERFORM log_user_activity(p_user_id, 'logout', 'User logged out');

    -- Also log this activity into the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NULL, -- No specific line item ID for general user activity
        'logout',
        v_username,
        'User logged out',
        v_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;
