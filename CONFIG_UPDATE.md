# Debezium Multi-Source CDC Configuration

This document provides an update on recent changes made to support multiple source databases with Debezium 3.0.0.

## Summary of Changes

1. Added support for multiple source databases:
   - MySQL (previously supported)
   - PostgreSQL (new)
   - MongoDB (new)
   - Oracle (new)
   - Cassandra (new)
2. Made the stack configurable through environment variables and profiles
3. Updated data generator to support all source databases
4. Added dynamic Debezium configuration based on selected source
5. Enhanced test scripts to validate different source configurations

## Source Database Configuration

You can now enable or disable source databases in the `.env` file:

```properties
# Feature flags to enable/disable source databases
ENABLE_MYSQL=true
ENABLE_POSTGRESQL=false
ENABLE_MONGODB_SOURCE=false
ENABLE_ORACLE=false
ENABLE_CASSANDRA=false

# Source Type - Options: mysql, postgresql, mongodb, oracle, cassandra
SOURCE_TYPE=mysql
```

The `SOURCE_TYPE` specifies which source connector Debezium will use. Only one source can be active at a time.

## Running with Specific Sources

Use the `run.sh` script with command-line options to start the stack with specific sources:

```bash
# Run with MySQL source only
./run.sh --mysql

# Run with PostgreSQL source only
./run.sh --postgresql

# Run with MongoDB source only
./run.sh --mongodb

# Run with Oracle source only
./run.sh --oracle

# Run with Cassandra source only
./run.sh --cassandra

# Run with multiple sources (only one will be active)
./run.sh --mysql --postgresql

# Run with all sources
./run.sh --all

# Clean data directories before starting
./run.sh --mysql --clean
```

## Testing Scripts

Three scripts are available to help test the configuration:

1. `run.sh` - Main script to start the stack with specified sources
2. `test_stack.sh` - Tests the full stack with all enabled sources
3. `test_rabbitmq.sh` - Tests just the RabbitMQ configuration

## Credential Configuration

The credentials are configured in the `.env` file for each source database:

- MySQL:
  - Root user: `root` / `debezium`
  - Debezium user: `debezium` / `dbz`
- PostgreSQL:
  - User: `postgres` / `postgres`
  - Debezium role: `debezium` / `dbz`
- MongoDB Source:
  - Admin user: `admin` / `admin`
- Oracle:
  - System user: Oracle default
  - Debezium user: `C##DBZUSER` / `dbz`
- Cassandra:
  - User: `cassandra` / `cassandra`
- RabbitMQ:
  - User: `guest` / `guest`
- MongoDB Sink:
  - Admin user: `admin` / `admin`

## Data Generator

The data generator supports all source databases and will detect which ones are enabled from environment variables. It uses a common data structure (customers and orders) across all sources.

## Debezium Configuration

Debezium is configured dynamically based on the selected source type using the `scripts/debezium-start.sh` script. This script creates the appropriate `application.properties` file for Debezium Server.

## Common Issues and Troubleshooting

1. **Source Database Connectivity**: Check that the source database is running and has the correct credentials
2. **Debezium Connector Issues**: Check Debezium logs for specific connector errors
3. **RabbitMQ Connectivity**: Use `test_rabbitmq.sh` to verify RabbitMQ setup
4. **Go Consumer Issues**: Check logs for connection or processing errors

## Additional Notes

- Make sure to restart all containers after updating the configuration
- When switching source types, clean the data directories with `--clean` flag to avoid conflicts
- Some source databases (like Oracle) may require additional setup steps
- Check the logs with `docker compose logs [service-name]` for detailed information
