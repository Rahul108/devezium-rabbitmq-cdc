-- Create the ecommerce database
CREATE DATABASE IF NOT EXISTS ecommerce;
USE ecommerce;

-- Create and populate the products table
CREATE TABLE products (
  product_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(100) NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create and populate the categories table
CREATE TABLE categories (
  category_id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial data for categories
INSERT INTO categories (name, description) VALUES
  ('Electronics', 'Electronic devices and gadgets'),
  ('Clothing', 'Apparel and fashion items'),
  ('Books', 'Physical and digital books'),
  ('Home & Garden', 'Home improvement and gardening items');

-- Insert initial data for products
INSERT INTO products (name, category, price, stock_quantity) VALUES
  ('Smartphone X1', 'Electronics', 599.99, 50),
  ('Laptop Pro', 'Electronics', 1299.99, 25),
  ('Cotton T-Shirt', 'Clothing', 19.99, 100),
  ('Denim Jeans', 'Clothing', 49.99, 75),
  ('Programming Guide', 'Books', 39.99, 30),
  ('Garden Tools Set', 'Home & Garden', 89.99, 20);

-- Grant permissions for debezium user on the new database
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON ecommerce.* TO 'debezium'@'%';
