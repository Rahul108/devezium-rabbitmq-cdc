#!/bin/bash

# High-throughput data generator runner script
# Usage: ./run_high_throughput_test.sh [TARGET_CPS] [DURATION] [CONCURRENCY]

set -e

# Default values
DEFAULT_TARGET_CPS=10000
DEFAULT_DURATION=60
DEFAULT_CONCURRENCY=50
DEFAULT_BATCH_SIZE=10

# Parse command line arguments
TARGET_CPS=${1:-$DEFAULT_TARGET_CPS}
DURATION_SECONDS=${2:-$DEFAULT_DURATION}
CONCURRENCY=${3:-$DEFAULT_CONCURRENCY}
BATCH_SIZE=${4:-$DEFAULT_BATCH_SIZE}

echo "🚀 Starting High-Throughput Data Generator Test"
echo "================================================"
echo "Target CPS: $TARGET_CPS"
echo "Duration: $DURATION_SECONDS seconds"
echo "Concurrency: $CONCURRENCY workers"
echo "Batch Size: $BATCH_SIZE operations per batch"
echo "================================================"

# Load existing environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set performance configuration
export TARGET_CPS=$TARGET_CPS
export DURATION_SECONDS=$DURATION_SECONDS
export CONCURRENCY=$CONCURRENCY
export BATCH_SIZE=$BATCH_SIZE
export LOG_INTERVAL_SECONDS=5

# Ensure MySQL and dependencies are running
echo "📋 Checking prerequisites..."
docker compose up -d mysql rabbitmq mongodb1 mongodb2

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check MySQL health
echo "🔍 Checking MySQL health..."
until docker compose exec mysql mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

echo "✅ MySQL is ready"

# Check RabbitMQ health
echo "🔍 Checking RabbitMQ health..."
until docker compose exec rabbitmq rabbitmqctl status > /dev/null 2>&1; do
    echo "Waiting for RabbitMQ to be ready..."
    sleep 2
done

echo "✅ RabbitMQ is ready"

# Rebuild data generator with latest code
echo "🔨 Building data generator..."
docker compose build data-generator

# Start Debezium if not running
echo "🔄 Starting Debezium..."
docker compose up -d debezium

# Wait a bit for Debezium to initialize
sleep 5

# Start the consumer to process events
echo "📥 Starting Go consumer..."
docker compose up -d go-consumer

# Run the high-throughput test
echo ""
echo "🏃 Running high-throughput data generation test..."
echo "Monitor the logs with: docker compose logs -f data-generator"
echo ""

# Create a temporary compose override for this test
cat > docker-compose.override.yml << EOF
services:
  data-generator:
    environment:
      - TARGET_CPS=$TARGET_CPS
      - DURATION_SECONDS=$DURATION_SECONDS
      - CONCURRENCY=$CONCURRENCY
      - BATCH_SIZE=$BATCH_SIZE
      - LOG_INTERVAL_SECONDS=5
EOF

# Run the data generator
docker compose run --rm data-generator

# Clean up override file
rm -f docker-compose.override.yml

echo ""
echo "✅ High-throughput test completed!"
echo ""
echo "📊 Check the results:"
echo "- Data generator logs: docker compose logs data-generator"
echo "- Debezium logs: docker compose logs debezium"
echo "- Consumer logs: docker compose logs go-consumer"
echo "- RabbitMQ management: http://localhost:15672 (admin/admin)"
echo ""
echo "🔍 To check queue metrics:"
echo "docker compose exec rabbitmq rabbitmqctl list_queues name messages"
echo ""
