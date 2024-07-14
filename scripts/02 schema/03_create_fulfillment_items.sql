-- version 0.5.1

-- Create fulfillment items table

CREATE TABLE fulfillment_items (
    fulfillment_item_id SERIAL PRIMARY KEY, -- Unique identifier for the fulfillment record
    order_line_item_id INT NOT NULL REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the fulfillment record was created
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the fulfillment record was last updated
    milstrip_req_no VARCHAR(50), -- Requisition or MILSTRIP number
    edd_to_ches DATE, -- Estimated delivery date to Chesapeake
    rcd_v2x_date DATE, -- Received at V2X date
    lot_id VARCHAR(15), -- Lot identifier
    triwall VARCHAR(15), -- Tri-wall identifier
    shipdoc_tcn VARCHAR(30), -- Shipping document TCN
    v2x_ship_no VARCHAR(20), -- V2X shipment number
    booking VARCHAR(20), -- Booking number
    vessel VARCHAR(30), -- Vessel name
    container VARCHAR(25), -- Container number
    sail_date DATE, -- Sail date
    edd_to_egypt DATE, -- Estimated delivery date to Egypt
    arr_lsc_egypt DATE, -- Arrival at LSC Egypt
    lsc_on_hand_date DATE, -- LSC on-hand date
    carrier VARCHAR(50), -- Carrier information for the shipment
    status_id INT REFERENCES statuses(status_id), -- Foreign key to statuses table
    created_by INT REFERENCES roles(role_id), -- User who created the fulfillment record
    updated_by VARCHAR(50), -- User who last updated the fulfillment record
    update_source VARCHAR(50) --where the most recent update comes from
    has_comments BOOLEAN DEFAULT FALSE, -- Indicates if any user comments have been added for the fulfillment record
    inquiry_status BOOLEAN DEFAULT FALSE, -- Flag set when review of the fulfillment record is requested
    UNIQUE (order_line_item_id, fulfillment_item_id) -- Ensures unique combination of order line item and fulfillment record
);

