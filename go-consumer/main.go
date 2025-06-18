package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/viper"
	"github.com/streadway/amqp"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Config represents the application configuration
type Config struct {
	RabbitMQ struct {
		URI          string `mapstructure:"uri"`
		QueueName    string `mapstructure:"queue_name"`
		ExchangeName string `mapstructure:"exchange_name"`
		ExchangeType string `mapstructure:"exchange_type"`
		RoutingKey   string `mapstructure:"routing_key"`
	} `mapstructure:"rabbitmq"`
	MongoDB []MongoDBConfig `mapstructure:"mongodb"`
}

// MongoDBConfig represents a MongoDB connection configuration
type MongoDBConfig struct {
	URI              string `mapstructure:"uri"`
	Database         string `mapstructure:"database"`
	CollectionPrefix string `mapstructure:"collection_prefix"`
}

// DebeziumEvent represents the structure of events from Debezium
type DebeziumEvent struct {
	Schema  json.RawMessage `json:"schema"`
	Payload json.RawMessage `json:"payload"`
}

// DebeziumPayload represents the structure of the payload part of a Debezium event
type DebeziumPayload struct {
	Before      json.RawMessage        `json:"before"`
	After       json.RawMessage        `json:"after"`
	Source      map[string]interface{} `json:"source"`
	Op          string                 `json:"op"`
	TsMs        int64                  `json:"ts_ms"`
	Transaction map[string]interface{} `json:"transaction"`
}

// SimplifiedCDCEvent represents the simplified structure we want to store in MongoDB
type SimplifiedCDCEvent struct {
	DatabaseName   string                 `json:"database_name"`
	TableName      string                 `json:"table_name"`
	Operation      string                 `json:"operation"`
	BeforeData     map[string]interface{} `json:"before_data,omitempty"`
	AfterData      map[string]interface{} `json:"after_data,omitempty"`
	Timestamp      time.Time              `json:"timestamp"`
	TransactionID  string                 `json:"transaction_id,omitempty"`
	BinlogPosition map[string]interface{} `json:"binlog_position,omitempty"`
}

func main() {
	// Load configuration
	cfg, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Connect to MongoDB instances
	mongoClients := make([]*mongo.Client, 0, len(cfg.MongoDB))
	for _, mongoConfig := range cfg.MongoDB {
		client, err := connectToMongoDB(mongoConfig.URI)
		if err != nil {
			log.Fatalf("Failed to connect to MongoDB at %s: %v", mongoConfig.URI, err)
		}
		defer client.Disconnect(context.Background())
		mongoClients = append(mongoClients, client)
	}

	// Connect to RabbitMQ
	rabbitConn, err := connectToRabbitMQ(cfg.RabbitMQ.URI)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer rabbitConn.Close()

	// Create a channel
	ch, err := rabbitConn.Channel()
	if err != nil {
		log.Fatalf("Failed to open a channel: %v", err)
	}
	defer ch.Close()

	// Declare the exchange
	err = ch.ExchangeDeclare(
		cfg.RabbitMQ.ExchangeName, // name
		cfg.RabbitMQ.ExchangeType, // type
		true,                      // durable
		false,                     // auto-deleted
		false,                     // internal
		false,                     // no-wait
		nil,                       // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare an exchange: %v", err)
	}

	// Declare a queue
	q, err := ch.QueueDeclare(
		cfg.RabbitMQ.QueueName, // name
		true,                   // durable
		false,                  // delete when unused
		false,                  // exclusive
		false,                  // no-wait
		nil,                    // arguments
	)
	if err != nil {
		log.Fatalf("Failed to declare a queue: %v", err)
	}

	// Bind the queue to the exchange
	err = ch.QueueBind(
		q.Name,      // queue name
		"#",         // routing key
		"amq.topic", // exchange
		false,
		nil,
	)
	if err != nil {
		log.Fatalf("Failed to bind a queue: %v", err)
	}

	// Start consuming
	msgs, err := ch.Consume(
		q.Name, // queue
		"",     // consumer
		false,  // auto-ack
		false,  // exclusive
		false,  // no-local
		false,  // no-wait
		nil,    // args
	)
	if err != nil {
		log.Fatalf("Failed to register a consumer: %v", err)
	}

	// Handle graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Process messages
	log.Println("Starting to consume messages...")
	go func() {
		for msg := range msgs {
			log.Printf("Received a message: %s", msg.RoutingKey)

			// Parse the message
			var event DebeziumEvent
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				log.Printf("Error unmarshalling message: %v", err)
				msg.Nack(false, false)
				continue
			}

			// Parse the payload
			var payload DebeziumPayload
			if err := json.Unmarshal(event.Payload, &payload); err != nil {
				log.Printf("Error unmarshalling payload: %v", err)
				msg.Nack(false, false)
				continue
			}

			// Create simplified event structure
			simplified := SimplifiedCDCEvent{
				Operation: getOperationName(payload.Op),
				Timestamp: time.Unix(0, payload.TsMs*int64(time.Millisecond)),
				BinlogPosition: map[string]interface{}{
					"file": payload.Source["file"],
					"pos":  payload.Source["pos"],
				},
			}

			// Extract database and table names from source
			if db, ok := payload.Source["db"].(string); ok {
				simplified.DatabaseName = db
			}
			if table, ok := payload.Source["table"].(string); ok {
				simplified.TableName = table
			}

			// Extract transaction ID if available
			if payload.Transaction != nil {
				if txID, ok := payload.Transaction["id"].(string); ok {
					simplified.TransactionID = txID
				}
			}

			// Parse before data if exists
			if len(payload.Before) > 0 && string(payload.Before) != "null" {
				var beforeData map[string]interface{}
				if err := json.Unmarshal(payload.Before, &beforeData); err == nil {
					simplified.BeforeData = beforeData
				} else {
					log.Printf("Error parsing before data: %v", err)
				}
			}

			// Parse after data if exists
			if len(payload.After) > 0 && string(payload.After) != "null" {
				var afterData map[string]interface{}
				if err := json.Unmarshal(payload.After, &afterData); err == nil {
					simplified.AfterData = afterData
				} else {
					log.Printf("Error parsing after data: %v", err)
				}
			}

			// Store in MongoDB
			for i, client := range mongoClients {
				mongoConfig := cfg.MongoDB[i]

				// Determine collection name based on routing key
				// For simplicity, we'll use the table name from the routing key
				parts := splitRoutingKey(msg.RoutingKey)
				collectionName := mongoConfig.CollectionPrefix
				if len(parts) > 0 {
					collectionName += "_" + parts[len(parts)-1]
				}

				// Insert into MongoDB
				collection := client.Database(mongoConfig.Database).Collection(collectionName)
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)

				_, err := collection.InsertOne(ctx, simplified)
				cancel()

				if err != nil {
					log.Printf("Error inserting into MongoDB %d: %v", i+1, err)
				} else {
					log.Printf("Successfully stored in MongoDB %d, collection: %s", i+1, collectionName)
				}
			}

			// Acknowledge the message
			msg.Ack(false)
		}
	}()

	// Wait for shutdown signal
	<-quit
	log.Println("Shutting down gracefully...")
}

// loadConfig loads the application configuration from file or environment variables
func loadConfig() (*Config, error) {
	// Set default values
	viper.SetDefault("rabbitmq.uri", "amqp://guest:guest@rabbitmq:5672/")
	viper.SetDefault("rabbitmq.queue_name", "mysql.events")
	viper.SetDefault("rabbitmq.exchange_name", "mysql-events")
	viper.SetDefault("rabbitmq.exchange_type", "topic")
	viper.SetDefault("rabbitmq.routing_key", "#")

	// Check environment variables
	rabbitURI := os.Getenv("RABBITMQ_URI")
	if rabbitURI != "" {
		viper.Set("rabbitmq.uri", rabbitURI)
	}

	// Set up MongoDB configs from environment variables
	var mongoConfigs []MongoDBConfig
	database := getEnvOrDefault("MONGODB_DATABASE", "cdc_data")
	collectionPrefix := getEnvOrDefault("MONGODB_COLLECTION_PREFIX", "mysql")

	// MongoDB 1
	mongoURI1 := os.Getenv("MONGODB_URI_1")
	if mongoURI1 != "" {
		mongoConfigs = append(mongoConfigs, MongoDBConfig{
			URI:              mongoURI1,
			Database:         database,
			CollectionPrefix: collectionPrefix,
		})
	}

	// MongoDB 2
	mongoURI2 := os.Getenv("MONGODB_URI_2")
	if mongoURI2 != "" {
		mongoConfigs = append(mongoConfigs, MongoDBConfig{
			URI:              mongoURI2,
			Database:         database,
			CollectionPrefix: collectionPrefix,
		})
	}

	// Check for config file
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("/app/config")
	viper.AddConfigPath("./config")

	// Read from config file if it exists
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
		// Config file not found, we'll use defaults and environment variables
	}

	// Create and populate config
	cfg := &Config{}
	if err := viper.Unmarshal(cfg); err != nil {
		return nil, fmt.Errorf("unable to decode config: %w", err)
	}

	// Add MongoDB configs from environment if not already set
	if len(cfg.MongoDB) == 0 {
		cfg.MongoDB = mongoConfigs
	}

	return cfg, nil
}

// connectToMongoDB establishes a connection to a MongoDB instance
func connectToMongoDB(uri string) (*mongo.Client, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
	if err != nil {
		return nil, err
	}

	// Ping the database to verify connection
	err = client.Ping(ctx, nil)
	if err != nil {
		return nil, err
	}

	log.Printf("Connected to MongoDB at %s", uri)
	return client, nil
}

// connectToRabbitMQ establishes a connection to RabbitMQ
func connectToRabbitMQ(uri string) (*amqp.Connection, error) {
	// Retry connection a few times
	var conn *amqp.Connection
	var err error

	for i := 0; i < 5; i++ {
		conn, err = amqp.Dial(uri)
		if err == nil {
			break
		}
		log.Printf("Failed to connect to RabbitMQ, retrying in 5 seconds: %v", err)
		time.Sleep(5 * time.Second)
	}

	if err != nil {
		return nil, err
	}

	log.Printf("Connected to RabbitMQ at %s", uri)
	return conn, nil
}

// splitRoutingKey splits a routing key into parts
func splitRoutingKey(key string) []string {
	var result []string
	start := 0
	for i := 0; i < len(key); i++ {
		if key[i] == '.' {
			if start < i {
				result = append(result, key[start:i])
			}
			start = i + 1
		}
	}
	if start < len(key) {
		result = append(result, key[start:])
	}
	return result
}

// getOperationName converts Debezium operation code to a human-readable name
func getOperationName(op string) string {
	switch op {
	case "c":
		return "create"
	case "u":
		return "update"
	case "d":
		return "delete"
	case "r":
		return "read"
	default:
		return op
	}
}

// getEnvOrDefault gets an environment variable or returns a default value if not set
func getEnvOrDefault(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
