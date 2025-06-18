-- Setup Cassandra keyspace and tables for Debezium CDC

-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS inventory WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Create tables
USE inventory;

CREATE TABLE IF NOT EXISTS customers (
    id int PRIMARY KEY,
    first_name text,
    last_name text,
    email text,
    created_at timestamp
);

CREATE TABLE IF NOT EXISTS orders (
    id int PRIMARY KEY,
    customer_id int,
    order_date timestamp,
    status text,
    total decimal
);

-- Insert sample data
INSERT INTO customers (id, first_name, last_name, email, created_at) VALUES 
(1, 'John', 'Doe', 'john.doe@example.com', toTimestamp(now()));
INSERT INTO customers (id, first_name, last_name, email, created_at) VALUES 
(2, 'Jane', 'Smith', 'jane.smith@example.com', toTimestamp(now()));
INSERT INTO customers (id, first_name, last_name, email, created_at) VALUES 
(3, 'Bob', 'Johnson', 'bob.johnson@example.com', toTimestamp(now()));
INSERT INTO customers (id, first_name, last_name, email, created_at) VALUES 
(4, 'Alice', 'Brown', 'alice.brown@example.com', toTimestamp(now()));
INSERT INTO customers (id, first_name, last_name, email, created_at) VALUES 
(5, 'Charlie', 'Davis', 'charlie.davis@example.com', toTimestamp(now()));

INSERT INTO orders (id, customer_id, order_date, status, total) VALUES 
(1, 1, toTimestamp(now()), 'COMPLETED', 99.99);
INSERT INTO orders (id, customer_id, order_date, status, total) VALUES 
(2, 1, toTimestamp(now()), 'PENDING', 15.50);
INSERT INTO orders (id, customer_id, order_date, status, total) VALUES 
(3, 2, toTimestamp(now()), 'CANCELLED', 25.75);
INSERT INTO orders (id, customer_id, order_date, status, total) VALUES 
(4, 3, toTimestamp(now()), 'COMPLETED', 75.25);
INSERT INTO orders (id, customer_id, order_date, status, total) VALUES 
(5, 4, toTimestamp(now()), 'PENDING', 35.50);
