-- Initialize PostgreSQL database for Debezium CDC testing
-- This script creates sample tables with test data

-- Create the test tables
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Create a user for Debezium with replication privileges
CREATE ROLE debezium REPLICATION LOGIN PASSWORD 'dbz';
GRANT ALL PRIVILEGES ON DATABASE inventory TO debezium;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO debezium;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO debezium;
ALTER TABLE customers OWNER TO debezium;
ALTER TABLE orders OWNER TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO debezium;

-- Create a publication for the tables we want to capture
CREATE PUBLICATION dbz_publication FOR TABLE customers, orders;

-- Insert sample data
INSERT INTO customers (first_name, last_name, email) VALUES
('John', 'Doe', 'john.doe@example.com'),
('Jane', 'Smith', 'jane.smith@example.com'),
('Bob', 'Johnson', 'bob.johnson@example.com'),
('Alice', 'Brown', 'alice.brown@example.com'),
('Charlie', 'Davis', 'charlie.davis@example.com');

INSERT INTO orders (customer_id, status, total) VALUES
(1, 'COMPLETED', 99.99),
(1, 'PENDING', 15.50),
(2, 'CANCELLED', 25.75),
(3, 'COMPLETED', 75.25),
(4, 'PENDING', 35.50);
