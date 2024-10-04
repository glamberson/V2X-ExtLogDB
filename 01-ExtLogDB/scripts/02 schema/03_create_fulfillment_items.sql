
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



