package main

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	// Get MySQL connection details from environment variables
	host := getEnv("MYSQL_HOST", "mysql")
	port := getEnv("MYSQL_PORT", "3306")
	user := getEnv("MYSQL_USER", "root")
	password := getEnv("MYSQL_PASSWORD", "debezium")
	dbName := getEnv("MYSQL_DATABASE", "inventory")

	// Connect to MySQL
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s", user, password, host, port, dbName)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to MySQL: %v", err)
	}
	defer db.Close()

	// Wait for MySQL to be ready
	for i := 0; i < 30; i++ {
		err = db.Ping()
		if err == nil {
			break
		}
		log.Printf("Waiting for MySQL to be ready... %v", err)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		log.Fatalf("MySQL is not ready after waiting: %v", err)
	}

	log.Println("Connected to MySQL successfully")

	// Seed the random number generator
	rand.Seed(time.Now().UnixNano())

	// Generate random data for customers and orders
	for i := 0; i < 10; i++ {
		// Insert a new customer
		customerID, err := insertCustomer(db)
		if err != nil {
			log.Printf("Failed to insert customer: %v", err)
			continue
		}

		// Insert orders for the new customer
		numOrders := rand.Intn(3) + 1 // 1-3 orders per customer
		for j := 0; j < numOrders; j++ {
			err := insertOrder(db, customerID)
			if err != nil {
				log.Printf("Failed to insert order: %v", err)
			}
		}

		// Wait a bit between insertions to make it easier to see the changes
		time.Sleep(1 * time.Second)
	}

	log.Println("Data generation completed successfully")
}

// insertCustomer inserts a new customer into the database
func insertCustomer(db *sql.DB) (int64, error) {
	// Generate a random customer
	firstName := randomFirstName()
	lastName := randomLastName()
	email := fmt.Sprintf("%s.%s@example.com", firstName, lastName)

	// Insert the customer
	result, err := db.Exec(
		"INSERT INTO customers (first_name, last_name, email) VALUES (?, ?, ?)",
		firstName, lastName, email,
	)
	if err != nil {
		return 0, err
	}

	// Get the ID of the inserted customer
	id, err := result.LastInsertId()
	if err != nil {
		return 0, err
	}

	log.Printf("Inserted customer: %s %s (ID: %d)", firstName, lastName, id)
	return id, nil
}

// insertOrder inserts a new order for a customer
func insertOrder(db *sql.DB, customerID int64) error {
	// Generate random order data
	orderDate := time.Now().AddDate(0, 0, -rand.Intn(30)) // Random date in the last 30 days
	total := 10.0 + rand.Float64()*990.0                  // Random total between $10 and $1000
	status := randomOrderStatus()

	// Insert the order
	_, err := db.Exec(
		"INSERT INTO orders (customer_id, order_date, total, status) VALUES (?, ?, ?, ?)",
		customerID, orderDate.Format("2006-01-02"), total, status,
	)
	if err != nil {
		return err
	}

	log.Printf("Inserted order for customer ID %d: $%.2f, status: %s", customerID, total, status)
	return nil
}

// randomFirstName returns a random first name
func randomFirstName() string {
	firstNames := []string{
		"James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
		"William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
		"Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
		"Matthew", "Margaret", "Anthony", "Betty", "Mark", "Sandra", "Donald", "Ashley",
	}
	return firstNames[rand.Intn(len(firstNames))]
}

// randomLastName returns a random last name
func randomLastName() string {
	lastNames := []string{
		"Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson",
		"Moore", "Taylor", "Anderson", "Thomas", "Jackson", "White", "Harris", "Martin",
		"Thompson", "Garcia", "Martinez", "Robinson", "Clark", "Rodriguez", "Lewis", "Lee",
		"Walker", "Hall", "Allen", "Young", "Hernandez", "King", "Wright", "Lopez",
	}
	return lastNames[rand.Intn(len(lastNames))]
}

// randomOrderStatus returns a random order status
func randomOrderStatus() string {
	statuses := []string{"PENDING", "PROCESSING", "COMPLETED", "SHIPPED", "DELIVERED", "CANCELLED"}
	return statuses[rand.Intn(len(statuses))]
}

// getEnv gets an environment variable or returns the default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
