CREATE TABLE report_record_links (
    link_id SERIAL PRIMARY KEY,
    staged_id INT REFERENCES staged_egypt_weekly_data(staged_id) ON DELETE CASCADE,
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE SET NULL,
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE SET NULL,
    
    -- Identifiers from staged data
    raw_data_id INT NOT NULL,
    system_identifier_code VARCHAR(50) NOT NULL,
    original_line INT NOT NULL,
    
    -- Additional fields for convenience
    report_name VARCHAR(255),
    report_date DATE,
    sheet_name VARCHAR(255),
    
    link_type VARCHAR(50) NOT NULL,        -- e.g., 'exact_match', 'partial_match', 'manual_review'
    confidence_score DECIMAL(5,2),         -- Optional: Confidence level of the match
    flags JSONB,                           -- Any additional flags or notes
    linked_by INT REFERENCES users(user_id),
    linked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    update_source TEXT,                    -- Reason or source of the link
    
    UNIQUE (staged_id, order_line_item_id, fulfillment_item_id),
    UNIQUE (raw_data_id, system_identifier_code),
    UNIQUE (raw_data_id, original_line)
);

-- Add indexes for improved query performance
CREATE INDEX idx_report_record_links_raw_data_id ON report_record_links(raw_data_id);
CREATE INDEX idx_report_record_links_system_identifier_code ON report_record_links(system_identifier_code);
CREATE INDEX idx_report_record_links_original_line ON report_record_links(original_line);
CREATE INDEX idx_report_record_links_report_info ON report_record_links(report_name, report_date, sheet_name);