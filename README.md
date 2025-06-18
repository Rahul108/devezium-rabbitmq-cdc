# Debezium CDC with RabbitMQ and MongoDB

This project demonstrates a Change Data Capture (CDC) solution using:
- Debezium Server 3.0.0.Final (standalone)
- MySQL as the source database
- RabbitMQ as the message broker
- Multiple MongoDB instances as sinks
- Go-based consumer for RabbitMQ to MongoDB

## Project Structure

```
debezium-cdc/
├── debezium-server/     # Debezium Server configuration
├── mysql/               # MySQL initialization scripts
├── mongodb/             # MongoDB data directories
├── rabbitmq/            # RabbitMQ data
├── go-consumer/         # Go-based RabbitMQ consumer
├── data-generator/      # Test data generator
└── docker-compose.yml   # Docker Compose configuration
```

## Requirements

- Docker and Docker Compose
- Internet connection to pull Docker images

## Version Information

This project uses:
- Debezium Server: 3.0.0.Final (official release)
- MySQL: 8.0
- RabbitMQ: 3.12 with Management UI
- MongoDB: 6.0
- Go: 1.21 for consumer and data generator

## Getting Started

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd debezium-cdc
   ```

2. Start the services:
   ```bash
   docker compose up -d
   ```

3. Generate test data (this will run automatically when the stack is deployed):
   ```bash
   docker compose up data-generator
   ```

4. Check the status of the services:
   ```bash
   docker compose ps
   ```

5. Monitor the CDC process:
   ```bash
   # View Debezium logs
   docker compose logs -f debezium
   
   # View consumer logs
   docker compose logs -f go-consumer
   ```

6. Verify setup (optional):
   ```bash
   ./verify-debezium-setup.sh
   ```

## Configuration

### Adding/Removing MongoDB Sinks

To add or remove MongoDB sinks:

1. Update the `docker-compose.yml` file to add/remove MongoDB services
2. Update the `go-consumer/config/config.yaml` file to add/remove MongoDB connections
3. Restart the services:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Modifying MySQL Source Tables

1. Edit the MySQL initialization script in `mysql/init/01-init.sql`
2. Update the Debezium configuration in `debezium-server/conf/application.properties` to include the new tables
3. Restart the services:
   ```bash
   docker compose down -v  # Use -v to remove volumes and start fresh
   docker compose up -d
   ```

### Changing RabbitMQ Configuration

1. Modify the RabbitMQ definitions in `rabbitmq/definitions.json`
2. Update the Debezium sink configuration in `debezium-server/conf/application.properties`
3. Restart the services:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Accessing Services

- RabbitMQ Management UI: http://localhost:15672 (guest/guest)
- MySQL: localhost:3306 (root/debezium)
- MongoDB 1: localhost:27017 (admin/admin)
- MongoDB 2: localhost:27018 (admin/admin)

## Troubleshooting

- **Debezium not capturing changes**: Check the Debezium logs with `docker compose logs debezium`. Make sure the MySQL binary logging is enabled and the user has appropriate permissions.
- **Consumer not receiving messages**: Check the RabbitMQ Management UI to verify that messages are being published to the expected queue.
- **Data not appearing in MongoDB**: Check the Go consumer logs with `docker compose logs go-consumer` for any connection or processing errors.
- **RabbitMQ connectivity issues**: Run `./verify-debezium-setup.sh` to diagnose common connectivity problems.

## Library Dependencies

The Debezium 3.0.0 setup uses the following external libraries:
- RabbitMQ Client: 5.19.0
- SLF4J API: 2.0.9
- SLF4J Simple: 2.0.9

These are automatically downloaded and installed by the setup scripts.
