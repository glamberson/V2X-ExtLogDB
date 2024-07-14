-- version 0.5.1



CREATE TABLE availability_events (
    availability_event_id SERIAL PRIMARY KEY, -- Unique identifier for the availability event
    availability_identifier VARCHAR(50) UNIQUE NOT NULL, -- Internal availability identifier used in CMMS
    availability_name VARCHAR(100) NOT NULL, -- Name of the availability event
    start_date DATE NOT NULL, -- Start date of the availability event
    end_date DATE NOT NULL, -- End date of the availability event
    description TEXT, -- Description of the availability event
    created_by INT REFERENCES users(user_id), -- User who created the availability event
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the availability event was created
);

