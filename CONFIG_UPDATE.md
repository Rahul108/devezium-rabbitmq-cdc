# Debezium CDC with RabbitMQ and MongoDB - Configuration Update

This document provides an update on recent changes made to fix RabbitMQ configuration issues when using Debezium 3.0.0.

## Summary of Changes

1. Fixed RabbitMQ `definitions.json` file to use proper password format instead of password hash
2. Added the admin user explicitly to RabbitMQ definitions
3. Ensured consistent use of admin credentials across services
4. Updated Debezium's application.properties to use admin credentials
5. Added test scripts for validating RabbitMQ configuration and the full stack

## Testing Scripts

Two new scripts have been added to help test the configuration:

1. `test_rabbitmq.sh` - Tests just the RabbitMQ configuration
2. `test_stack.sh` - Tests the full stack including Debezium, RabbitMQ, and Go consumer

## Credential Configuration

The following credentials are now consistently used across the stack:

- RabbitMQ:
  - Admin user: `admin` / `admin`
  - Guest user: `guest` / `guest` (standard default user, maintained for fallback)
- MongoDB:
  - Admin user: `admin` / `admin`
- MySQL:
  - Root user: `root` / `debezium`
  - Debezium user: `debezium` / `dbz`

## Common Issues Fixed

1. **RabbitMQ Crashing**: Fixed by using proper password format in definitions.json
2. **Debezium-RabbitMQ Connection Failure**: Fixed by ensuring consistent credentials
3. **Go Consumer Connection Failure**: Fixed by updating connection URI to use admin credentials

## Additional Notes

- Make sure to restart all containers after updating the configuration
- If you see connectivity issues, run the `test_rabbitmq.sh` script to verify RabbitMQ setup
- Check the logs with `docker compose logs [service-name]` for detailed information
