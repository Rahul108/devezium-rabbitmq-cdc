# Environment Configuration

This project uses a centralized environment configuration through `.env` files to avoid duplicating configuration across different services.

## Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file to customize your configuration:
   ```bash
   nano .env
   ```

## Configuration Structure

The configuration is organized into several sections:

- **General Configuration**: Versions and network ports
- **MySQL Configuration**: Database credentials and server settings
- **RabbitMQ Configuration**: Message broker settings
- **MongoDB Configuration**: Database connection settings
- **Debezium Configuration**: CDC engine configuration

## Using Environment Variables

All services in the docker-compose.yml file use these environment variables. If you need to add a new service or modify an existing one, refer to the environment variables defined in the `.env` file.

## Adding MongoDB Instances

To add additional MongoDB instances:

1. Add the MongoDB service in docker-compose.yml
2. Add the MongoDB connection details in .env
3. Update the go-consumer code to handle the additional connection

## Note on Kafka

While this project uses Debezium (which was originally built on Kafka Connect), it does not use Kafka as a message broker. It uses RabbitMQ instead. The only Kafka component used is the `org.apache.kafka.connect.transforms.RegexRouter` class, which is a utility for message routing and doesn't require an actual Kafka broker.
