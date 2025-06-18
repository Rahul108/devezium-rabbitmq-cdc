// Initialize MongoDB replica set for Debezium CDC
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-source:27017" }
  ]
});

// Wait for the replica set to initialize
sleep(1000);

// Switch to the admin database
db = db.getSiblingDB('admin');

// Create a user for Debezium
db.createUser({
  user: 'admin',
  pwd: 'admin',
  roles: [
    { role: 'root', db: 'admin' },
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' },
    { role: 'readWriteAnyDatabase', db: 'admin' }
  ]
});

// Authenticate as the admin user
db.auth('admin', 'admin');

// Switch to the inventory database
db = db.getSiblingDB('inventory');

// Create collections
db.createCollection('customers');
db.createCollection('orders');

// Insert sample data
db.customers.insertMany([
  {
    _id: 1001,
    first_name: 'John',
    last_name: 'Doe',
    email: 'john.doe@example.com',
    created_at: new Date()
  },
  {
    _id: 1002,
    first_name: 'Jane',
    last_name: 'Smith',
    email: 'jane.smith@example.com',
    created_at: new Date()
  },
  {
    _id: 1003,
    first_name: 'Bob',
    last_name: 'Johnson',
    email: 'bob.johnson@example.com',
    created_at: new Date()
  },
  {
    _id: 1004,
    first_name: 'Alice',
    last_name: 'Brown',
    email: 'alice.brown@example.com',
    created_at: new Date()
  },
  {
    _id: 1005,
    first_name: 'Charlie',
    last_name: 'Davis',
    email: 'charlie.davis@example.com',
    created_at: new Date()
  }
]);

db.orders.insertMany([
  {
    _id: 2001,
    customer_id: 1001,
    order_date: new Date(),
    status: 'COMPLETED',
    total: 99.99
  },
  {
    _id: 2002,
    customer_id: 1001,
    order_date: new Date(),
    status: 'PENDING',
    total: 15.50
  },
  {
    _id: 2003,
    customer_id: 1002,
    order_date: new Date(),
    status: 'CANCELLED',
    total: 25.75
  },
  {
    _id: 2004,
    customer_id: 1003,
    order_date: new Date(),
    status: 'COMPLETED',
    total: 75.25
  },
  {
    _id: 2005,
    customer_id: 1004,
    order_date: new Date(),
    status: 'PENDING',
    total: 35.50
  }
]);
