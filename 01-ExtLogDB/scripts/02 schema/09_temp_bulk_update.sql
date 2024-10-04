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

