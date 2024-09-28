CREATE TABLE quality_checked_records (
    quality_check_id SERIAL PRIMARY KEY,
    staged_id INT REFERENCES staged_egypt_weekly_data(staged_id),
    
    -- Overall Scores
    overall_quality_score DECIMAL(5,2),
    data_integrity_score DECIMAL(5,2),
    consistency_score DECIMAL(5,2),
    completeness_score DECIMAL(5,2),
    
    -- Individual Check Results
    jcn_twcode_valid BOOLEAN,
    suffix_check_result BOOLEAN,
    details_match_result BOOLEAN,
    is_new_record BOOLEAN,
    is_missing_from_current BOOLEAN,
    has_duplicates BOOLEAN,
    
    -- Flags
    manual_review_required BOOLEAN DEFAULT FALSE,
    processing_flags JSONB,
    
    -- Detailed Check Results
    check_details JSONB,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX idx_quality_checked_records_staged_id 
ON quality_checked_records(staged_id);

