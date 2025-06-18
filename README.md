# Debezium CDC with RabbitMQ and MongoDB

This project demonstrates a Change Data Capture (CDC) solution using:
- Debezium Server 3.0.0.Final (standalone)
- Multiple source databases (MySQL, PostgreSQL, MongoDB, Oracle, Cassandra)
- RabbitMQ as the message broker
- Multiple MongoDB instances as sinks
- Go-based consumer for RabbitMQ to MongoDB

## Project Structure

```
debezium-cdc/
├── debezium-server/     # Debezium Server configuration
├── mysql/               # MySQL initialization scripts
├── postgresql/          # PostgreSQL initialization scripts
├── mongodb-source/      # MongoDB source setup
├── oracle/              # Oracle setup
├── cassandra/           # Cassandra setup
├── mongodb/             # MongoDB sink data directories
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

2. Configure your environment:
   ```bash
   cp .env.example .env
   # Edit .env to enable/disable specific source databases
   ```

3. Start the services:
   ```bash
   docker compose up -d
   ```

   Alternatively, you can use the run.sh script to start specific source databases:
   ```bash
   # Start with MySQL source only
   ./run.sh --mysql
   
   # Start with PostgreSQL and MongoDB sources
   ./run.sh --postgresql --mongodb
   
   # Start with all sources
   ./run.sh --all
   
   # Clean all data before starting
   ./run.sh --mysql --clean
   ```

4. Generate test data (this will run automatically when the stack is deployed):
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

6. Testing the stack:
   ```bash
   # Test RabbitMQ configuration
   ./test_rabbitmq.sh
   
   # Test the entire stack
   ./test_stack.sh
   ```

## Configuration

### Enabling/Disabling Source Databases

You can enable or disable specific source databases by editing the `.env` file:

```
# Source database selection (true/false)
ENABLE_MYSQL=true
ENABLE_POSTGRESQL=false
ENABLE_MONGODB_SOURCE=false
ENABLE_ORACLE=false
ENABLE_CASSANDRA=false
```

After changing these settings, restart the stack:
```bash
docker compose down
docker compose up -d
```

### Adding/Removing MongoDB Sinks

To add or remove MongoDB sinks:

1. Update the `docker-compose.yml` file to add/remove MongoDB services
2. Update the `go-consumer/config/config.yaml` file to add/remove MongoDB connections
3. Restart the services:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Modifying Source Database Tables/Collections

#### MySQL
1. Edit the MySQL initialization script in `mysql/init/`
2. Update the `.env` file to include the new tables in `MYSQL_SOURCE_TABLE_INCLUDE_LIST`

#### PostgreSQL
1. Edit the PostgreSQL initialization script in `postgresql/init/`
2. Update the `.env` file to include the new tables in `POSTGRESQL_SOURCE_TABLE_INCLUDE_LIST`

#### MongoDB
1. Update the `.env` file to include the new collections in `MONGODB_SOURCE_COLLECTION_INCLUDE_LIST`

#### Oracle
1. Edit the Oracle initialization script in `oracle/setup/`
2. Update the `.env` file to include the new tables in `ORACLE_SOURCE_TABLE_INCLUDE_LIST`

#### Cassandra
1. Edit the Cassandra initialization script in `cassandra/init/`
2. Update the `.env` file to include the new tables in `CASSANDRA_SOURCE_TABLE_INCLUDE_LIST`

After making changes, restart the services:
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
- PostgreSQL: localhost:5432 (postgres/postgres)
- MongoDB Source: localhost:27017 (admin/admin)
- Oracle: localhost:1521 (sys/oracle)
- Cassandra: localhost:9042 (cassandra/cassandra)
- MongoDB Sink 1: localhost:27017 (admin/admin)
- MongoDB Sink 2: localhost:27018 (admin/admin)

## Troubleshooting

- **Debezium not capturing changes**: Check the Debezium logs with `docker compose logs debezium`. Make sure the source database binary logging or equivalent is enabled and the user has appropriate permissions.
- **Debezium container fails to start with "run.sh not found"**: This is usually due to incorrect paths in the container. The script now tries multiple startup methods automatically.
- **Permission denied when writing application.properties**: The script now uses `cp` instead of `mv` to avoid cross-device move issues.
- **"No sources enabled" message**: Check your `.env` file and ensure at least one `ENABLE_*` variable is set to `true`.
- **Consumer not receiving messages**: Check the RabbitMQ Management UI to verify that messages are being published to the expected queue.
- **Data not appearing in MongoDB**: Check the Go consumer logs with `docker compose logs go-consumer` for any connection or processing errors.
- **Source database connectivity issues**: Check that the source database is healthy with `docker compose ps` and that the initialization scripts have run correctly.

## Library Dependencies

The Debezium 3.0.0 setup uses the following external libraries:
- RabbitMQ Client: 5.19.0
- SLF4J API: 2.0.9
- SLF4J Simple: 2.0.9

These are automatically downloaded and installed by the setup scripts.
