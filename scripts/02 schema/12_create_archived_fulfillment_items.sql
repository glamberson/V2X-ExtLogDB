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

