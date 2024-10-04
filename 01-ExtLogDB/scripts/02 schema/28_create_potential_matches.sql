-- Drop the table if it already exists (be cautious with this in production)
DROP TABLE IF EXISTS potential_matches;

-- Create the potential_matches table
CREATE TABLE potential_matches (
    potential_match_id SERIAL PRIMARY KEY,
    staged_id INT NOT NULL REFERENCES staged_egypt_weekly_data(staged_id) ON DELETE CASCADE,
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE SET NULL,
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE SET NULL,
    match_score DECIMAL(5,2) NOT NULL CHECK (match_score >= 0 AND match_score <= 100),
    match_grade VARCHAR(20) NOT NULL,
    matched_fields TEXT[] NOT NULL,
    mismatched_fields TEXT[] NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN NOT NULL DEFAULT FALSE,
    decision VARCHAR(20) CHECK (decision IN ('Accepted', 'Rejected', 'Deferred')) DEFAULT 'Deferred',
    admin_notes TEXT,
    CONSTRAINT fk_potential_matches_staged_id FOREIGN KEY (staged_id)
        REFERENCES staged_egypt_weekly_data (staged_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_potential_matches_order_line_item_id FOREIGN KEY (order_line_item_id)
        REFERENCES MRL_line_items (order_line_item_id)
        ON DELETE SET NULL,
    CONSTRAINT fk_potential_matches_fulfillment_item_id FOREIGN KEY (fulfillment_item_id)
        REFERENCES fulfillment_items (fulfillment_item_id)
        ON DELETE SET NULL
);

-- Indexes to improve query performance
CREATE INDEX idx_potential_matches_staged_id ON potential_matches (staged_id);
CREATE INDEX idx_potential_matches_processed ON potential_matches (processed);
CREATE INDEX idx_potential_matches_decision ON potential_matches (decision);

