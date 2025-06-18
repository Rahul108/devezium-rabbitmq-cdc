#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Debezium CDC with RabbitMQ and MongoDB...${NC}"

# Remove any test scripts
rm -f test_connectivity.sh reset_and_restart.sh diagnose.sh 2>/dev/null

# Create data directories if they don't exist
mkdir -p debezium-server/data
mkdir -p mysql/data
mkdir -p mongodb/data1
mkdir -p mongodb/data2
mkdir -p rabbitmq/data

# Build and start the infrastructure services
echo -e "${GREEN}Starting MySQL, RabbitMQ, and MongoDB...${NC}"
docker compose up -d mysql rabbitmq mongodb1 mongodb2

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 20

# Install RabbitMQ libraries to Debezium
echo -e "${GREEN}Setting up RabbitMQ libraries for Debezium...${NC}"
./setup-rabbitmq-lib.sh

# Start Debezium server
echo -e "${GREEN}Starting Debezium server...${NC}"
docker compose up -d debezium

# Wait for Debezium to initialize
echo -e "${YELLOW}Waiting for Debezium to initialize...${NC}"
sleep 10

# Check Debezium logs
echo -e "${GREEN}Checking Debezium logs...${NC}"
docker compose logs debezium

# Start Go consumer
echo -e "${GREEN}Starting Go consumer...${NC}"
docker compose up -d go-consumer

# Generate test data
echo -e "${YELLOW}Generating test data...${NC}"
docker compose up --build data-generator

echo -e "${GREEN}Showing container status:${NC}"
docker compose ps

echo -e "${GREEN}Done! The CDC pipeline is now running.${NC}"
echo "Use the following commands to interact with the system:"
echo "- docker compose logs -f debezium    # Follow Debezium logs"
echo "- docker compose logs -f go-consumer # Follow consumer logs"
echo "- docker compose down                # Stop all services"
