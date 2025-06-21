package main

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

// Configuration struct
type Config struct {
	TargetCPS       int           // Target changes per second
	DurationSeconds int           // How long to run the test
	Concurrency     int           // Number of concurrent workers
	BatchSize       int           // Number of operations per batch
	LogInterval     time.Duration // How often to log progress
}

// Stats for tracking performance
type Stats struct {
	TotalOperations int64
	StartTime       time.Time
	LastLogTime     time.Time
	LastCount       int64
}

func main() {
	// Load configuration from environment variables
	config := loadConfig()
	
	log.Printf("Starting high-throughput data generator with config: %+v", config)

	// Get MySQL connection details from environment variables
	host := getEnv("MYSQL_HOST", "mysql")
	port := getEnv("MYSQL_PORT", "3306")
	user := getEnv("MYSQL_USER", "root")
	password := getEnv("MYSQL_PASSWORD", "debezium")
	dbName := getEnv("MYSQL_DATABASE", "inventory")

	// Connect to MySQL
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&multiStatements=true", user, password, host, port, dbName)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to MySQL: %v", err)
	}
	defer db.Close()

	// Configure connection pool for high concurrency
	db.SetMaxOpenConns(config.Concurrency * 2)
	db.SetMaxIdleConns(config.Concurrency)
	db.SetConnMaxLifetime(5 * time.Minute)

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

	// Initialize stats
	stats := &Stats{
		StartTime:   time.Now(),
		LastLogTime: time.Now(),
	}

	// Start stats logging goroutine
	go logStats(stats, config.LogInterval)

	// Calculate operations per worker
	targetOpsPerSecond := config.TargetCPS
	opsPerWorker := targetOpsPerSecond / config.Concurrency
	if opsPerWorker == 0 {
		opsPerWorker = 1
	}

	// Start worker goroutines
	var wg sync.WaitGroup
	quit := make(chan struct{})

	for i := 0; i < config.Concurrency; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			worker(db, workerID, opsPerWorker, config.BatchSize, stats, quit)
		}(i)
	}

	// Run for specified duration
	time.Sleep(time.Duration(config.DurationSeconds) * time.Second)
	close(quit)

	// Wait for all workers to finish
	wg.Wait()

	// Final stats
	duration := time.Since(stats.StartTime)
	totalOps := atomic.LoadInt64(&stats.TotalOperations)
	actualCPS := float64(totalOps) / duration.Seconds()

	log.Printf("Data generation completed!")
	log.Printf("Total operations: %d", totalOps)
	log.Printf("Duration: %v", duration)
	log.Printf("Actual CPS: %.2f", actualCPS)
	log.Printf("Target CPS: %d", config.TargetCPS)
	log.Printf("Efficiency: %.2f%%", (actualCPS/float64(config.TargetCPS))*100)
}

// loadConfig loads configuration from environment variables
func loadConfig() Config {
	return Config{
		TargetCPS:       getEnvInt("TARGET_CPS", 10000),
		DurationSeconds: getEnvInt("DURATION_SECONDS", 60),
		Concurrency:     getEnvInt("CONCURRENCY", 50),
		BatchSize:       getEnvInt("BATCH_SIZE", 10),
		LogInterval:     time.Duration(getEnvInt("LOG_INTERVAL_SECONDS", 5)) * time.Second,
	}
}

// worker function that generates data continuously
func worker(db *sql.DB, workerID int, opsPerSecond int, batchSize int, stats *Stats, quit <-chan struct{}) {
	rand.Seed(time.Now().UnixNano() + int64(workerID))
	
	// Calculate sleep duration between batches to achieve target ops/second
	// Each batch produces 'batchSize' operations
	// To achieve 'opsPerSecond', we need to execute a batch every (batchSize / opsPerSecond) seconds
	batchInterval := time.Duration(float64(batchSize)/float64(opsPerSecond)*1000) * time.Millisecond
	
	// Minimum interval to avoid overwhelming the database
	if batchInterval < 10*time.Millisecond {
		batchInterval = 10 * time.Millisecond
	}

	ticker := time.NewTicker(batchInterval)
	defer ticker.Stop()

	for {
		select {
		case <-quit:
			return
		case <-ticker.C:
			// Execute a batch of operations
			ops := executeBatch(db, batchSize, workerID)
			atomic.AddInt64(&stats.TotalOperations, int64(ops))
		}
	}
}

// executeBatch performs a batch of database operations
func executeBatch(db *sql.DB, batchSize int, workerID int) int {
	successCount := 0
	
	// Mix of different operations for variety
	for i := 0; i < batchSize; i++ {
		operation := rand.Intn(3) // 3 different types of operations
		
		switch operation {
		case 0: // Insert customer
			if insertCustomer(db) {
				successCount++
			}
		case 1: // Insert order (with existing customer)
			if insertRandomOrder(db) {
				successCount++
			}
		case 2: // Update existing record
			if updateRandomRecord(db) {
				successCount++
			}
		}
	}
	
	return successCount
}

// logStats periodically logs performance statistics
func logStats(stats *Stats, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now()
		totalOps := atomic.LoadInt64(&stats.TotalOperations)
		
		// Calculate current CPS
		timeSinceStart := now.Sub(stats.StartTime).Seconds()
		overallCPS := float64(totalOps) / timeSinceStart
		
		// Calculate recent CPS
		timeSinceLastLog := now.Sub(stats.LastLogTime).Seconds()
		recentOps := totalOps - stats.LastCount
		recentCPS := float64(recentOps) / timeSinceLastLog
		
		log.Printf("Stats - Total ops: %d, Overall CPS: %.2f, Recent CPS: %.2f, Duration: %.1fs", 
			totalOps, overallCPS, recentCPS, timeSinceStart)
		
		stats.LastLogTime = now
		stats.LastCount = totalOps
	}
}

// insertCustomer inserts a new customer into the database (optimized)
func insertCustomer(db *sql.DB) bool {
	// Generate a random customer
	firstName := randomFirstName()
	lastName := randomLastName()
	email := fmt.Sprintf("%s.%s+%d@example.com", firstName, lastName, rand.Intn(10000))

	// Insert the customer
	_, err := db.Exec(
		"INSERT INTO customers (first_name, last_name, email) VALUES (?, ?, ?)",
		firstName, lastName, email,
	)
	
	return err == nil
}

// insertRandomOrder inserts an order for a random existing customer
func insertRandomOrder(db *sql.DB) bool {
	// Get a random customer ID (assuming we have customers)
	var customerID int64
	err := db.QueryRow("SELECT id FROM customers ORDER BY RAND() LIMIT 1").Scan(&customerID)
	if err != nil {
		// If no customers exist, create one first
		if insertCustomer(db) {
			err = db.QueryRow("SELECT LAST_INSERT_ID()").Scan(&customerID)
			if err != nil {
				return false
			}
		} else {
			return false
		}
	}

	// Generate random order data
	orderDate := time.Now().AddDate(0, 0, -rand.Intn(30)) // Random date in the last 30 days
	total := 10.0 + rand.Float64()*990.0                  // Random total between $10 and $1000
	status := randomOrderStatus()

	// Insert the order
	_, err = db.Exec(
		"INSERT INTO orders (customer_id, order_date, total, status) VALUES (?, ?, ?, ?)",
		customerID, orderDate.Format("2006-01-02"), total, status,
	)
	
	return err == nil
}

// updateRandomRecord updates a random existing record to trigger UPDATE events
func updateRandomRecord(db *sql.DB) bool {
	operation := rand.Intn(2)
	
	switch operation {
	case 0: // Update customer email
		_, err := db.Exec(
			"UPDATE customers SET email = CONCAT(first_name, '.', last_name, '+', ?, '@example.com') WHERE id >= (SELECT FLOOR(RAND() * (SELECT MAX(id) FROM customers)) + 1) LIMIT 1",
			rand.Intn(10000),
		)
		return err == nil
		
	case 1: // Update order status
		newStatus := randomOrderStatus()
		_, err := db.Exec(
			"UPDATE orders SET status = ? WHERE id >= (SELECT FLOOR(RAND() * (SELECT MAX(id) FROM orders)) + 1) LIMIT 1",
			newStatus,
		)
		return err == nil
	}
	
	return false
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

// randomProductName returns a random product name
func randomProductName() string {
	products := []string{
		"Wireless Headphones", "Smart Watch", "Gaming Keyboard", "USB-C Cable", "Bluetooth Speaker",
		"Cotton T-Shirt", "Denim Jacket", "Running Shoes", "Winter Coat", "Baseball Cap",
		"Programming Book", "Science Fiction Novel", "Cookbook", "Art Guide", "History Book",
		"Garden Hose", "Plant Pot", "Garden Tools", "LED Light Bulb", "Kitchen Knife",
		"Coffee Mug", "Water Bottle", "Backpack", "Phone Case", "Laptop Stand",
	}
	return products[rand.Intn(len(products))]
}

// randomCategory returns a random product category
func randomCategory() string {
	categories := []string{"Electronics", "Clothing", "Books", "Home & Garden"}
	return categories[rand.Intn(len(categories))]
}

// getEnv gets an environment variable or returns the default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// getEnvInt gets an environment variable as integer or returns the default value
func getEnvInt(key string, defaultValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	
	intValue, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("Warning: Invalid integer value for %s: %s, using default: %d", key, value, defaultValue)
		return defaultValue
	}
	
	return intValue
}
