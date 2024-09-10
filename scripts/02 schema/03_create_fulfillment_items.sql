-- version 0.10.2

-- Create fulfillment items table (added MILSTRIP/req field)(added carrier field)

-- Create fulfillment_items table
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
    carrier VARCHAR(50),
    sail_date DATE, -- Sail date
    edd_to_ches DATE, -- Estimated delivery date to Chesapeake warehouse
    rcd_v2x_date DATE, -- Received by V2X date
    lot_id VARCHAR(30), -- Lot ID
    triwall VARCHAR(30), -- Triwall number
    lsc_on_hand_date DATE, -- LSC on-hand date
    arr_lsc_egypt DATE, -- Arrival at LSC Egypt date
    milstrip_req_no VARCHAR(25), -- Requisition or MILSTRIP number
    inquiry_status BOOLEAN DEFAULT FALSE, -- Flag set when review of the fulfillment item is requested
    comments TEXT -- Comments regarding the fulfillment item
);

