-- version 0.5.1


CREATE TABLE line_item_comments (
    comment_id SERIAL PRIMARY KEY, -- Unique identifier for the comment
    order_line_item_id INT, -- Foreign key to MRL line items or fulfillment items
    fulfillment_item_id INT, -- Foreign key to fulfillment items or NULL if it refers to MRL line item
    comment TEXT, -- The comment text
    commented_by VARCHAR(100), -- User who made the comment
    commented_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp with timezone when the comment was made
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    CHECK ((order_line_item_id IS NOT NULL AND fulfillment_item_id IS NULL) OR 
           (order_line_item_id IS NULL AND fulfillment_item_id IS NOT NULL)) -- Ensure only one of the two fields is set
);

