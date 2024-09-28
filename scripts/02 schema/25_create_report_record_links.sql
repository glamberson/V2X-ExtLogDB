CREATE TABLE report_record_links (
    link_id SERIAL PRIMARY KEY,
    staged_id INT REFERENCES staged_egypt_weekly_data(staged_id) ON DELETE CASCADE,
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE SET NULL,
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE SET NULL,
    link_type VARCHAR(50) NOT NULL,        -- e.g., 'exact_match', 'partial_match', 'manual_review'
    confidence_score DECIMAL(5,2),         -- Optional: Confidence level of the match
    flags JSONB,                           -- Any additional flags or notes
    linked_by INT REFERENCES users(user_id),
    linked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    update_source TEXT,                    -- Reason or source of the link
    UNIQUE (staged_id, order_line_item_id, fulfillment_item_id)
);
