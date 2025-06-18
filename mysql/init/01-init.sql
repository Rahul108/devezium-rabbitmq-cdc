-- Create the inventory database
CREATE DATABASE IF NOT EXISTS inventory;
USE inventory;

-- Create and populate the customers table
CREATE TABLE customers (
  id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create and populate the orders table
CREATE TABLE orders (
  order_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id INTEGER NOT NULL,
  order_date DATE NOT NULL,
  total DECIMAL(10, 2) NOT NULL,
  status VARCHAR(20) NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Insert initial data
INSERT INTO customers (first_name, last_name, email) VALUES
  ('John', 'Doe', 'john.doe@example.com'),
  ('Jane', 'Smith', 'jane.smith@example.com'),
  ('Bob', 'Johnson', 'bob.johnson@example.com');

INSERT INTO orders (customer_id, order_date, total, status) VALUES
  (1, '2023-01-15', 99.99, 'COMPLETED'),
  (2, '2023-01-16', 149.99, 'PENDING'),
  (3, '2023-01-17', 24.99, 'COMPLETED');

-- Create a user for Debezium with required permissions
CREATE USER IF NOT EXISTS 'debezium'@'%' IDENTIFIED BY 'dbz';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'debezium'@'%';
