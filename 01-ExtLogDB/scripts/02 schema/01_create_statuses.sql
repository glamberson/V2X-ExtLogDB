-- version 0.5.1


CREATE TABLE statuses (
    status_id SERIAL PRIMARY KEY, -- Unique identifier for the status
    status_name VARCHAR(50) UNIQUE NOT NULL, -- Name of the status, must be unique
    status_value INT NOT NULL -- Numeric value representing the status progression
);



-- Insert predefined statuses with the correct order
INSERT INTO statuses (status_name, status_value) VALUES
    ('NOT ORDERED', 10),
    ('INIT PROCESS', 20),
    ('ON ORDER', 30),
    ('RCD CHES WH', 40),
    ('PROC CHES WH', 50),
    ('READY TO SHIP', 60),
    ('FREIGHT FORWARDER', 70),
    ('EN ROUTE TO EGYPT', 80),
    ('ADMINISTRATIVELY REORDERED', 85),
    ('ARR EGYPT', 90),
    ('CORRECTION', 95),
    ('PARTIALLY RECEIVED', 100),
    ('ON HAND EGYPT', 110);
