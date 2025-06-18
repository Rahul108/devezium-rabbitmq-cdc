#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Verifying Debezium 3.0.0 setup...${NC}"

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check if we have the correct Debezium image
echo -e "${YELLOW}Checking Debezium image...${NC}"
docker pull debezium/server:3.0.0.Final
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to pull Debezium 3.0.0 image. Please check your internet connection.${NC}"
    exit 1
fi

# Start the services
echo -e "${GREEN}Starting services...${NC}"
docker compose down -v
docker compose up -d mysql rabbitmq

# Wait for MySQL and RabbitMQ to be ready
echo -e "${YELLOW}Waiting for MySQL and RabbitMQ to be ready...${NC}"
sleep 20

# Setup RabbitMQ libraries
echo -e "${GREEN}Setting up RabbitMQ libraries...${NC}"
./setup-rabbitmq-lib.sh

# Start Debezium
echo -e "${GREEN}Starting Debezium...${NC}"
docker compose up -d debezium

# Wait for Debezium to initialize
echo -e "${YELLOW}Waiting for Debezium to initialize...${NC}"
sleep 15

# Check Debezium logs
echo -e "${GREEN}Checking Debezium logs:${NC}"
docker compose logs debezium | tail -n 30

# Check if Debezium is connected to RabbitMQ
echo -e "${YELLOW}Checking Debezium-RabbitMQ connection...${NC}"
if docker compose logs debezium | grep -q "Connected to RabbitMQ"; then
    echo -e "${GREEN}✓ Debezium successfully connected to RabbitMQ!${NC}"
else
    echo -e "${YELLOW}⚠ Connection status not found in logs. Let's check for errors:${NC}"
    docker compose logs debezium | grep -i "error\|exception" | tail -n 10
fi

# Generate test data
echo -e "${GREEN}Generating test data...${NC}"
docker compose up -d --build data-generator

# Start consumer
echo -e "${GREEN}Starting Go consumer...${NC}"
docker compose up -d go-consumer

# Check consumer logs
echo -e "${YELLOW}Checking consumer logs:${NC}"
sleep 10
docker compose logs go-consumer | tail -n 20

# Check MongoDB for data
echo -e "${GREEN}Checking MongoDB for data...${NC}"
echo "To check MongoDB data, run:"
echo "docker exec -it mongodb1 mongosh -u admin -p admin --eval 'use cdc_data; db.mysql_customers.find()'"

echo -e "${GREEN}Verification complete!${NC}"
echo "If you see any errors, check the detailed logs with:"
echo "docker compose logs -f [service_name]"
