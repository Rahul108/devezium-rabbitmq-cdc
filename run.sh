#!/bin/bash

# Script to run and test the Debezium CDC solution

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Debezium CDC with RabbitMQ and MongoDB...${NC}"

# Build and start all services except the data generator
echo -e "${GREEN}Building and starting services...${NC}"
docker compose up -d --build mysql rabbitmq mongodb1 mongodb2 debezium go-consumer

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 20

# Check if all services are running
echo -e "${GREEN}Checking service status...${NC}"
docker compose ps

# Generate test data
echo -e "${YELLOW}Generating test data...${NC}"
docker compose up --build data-generator

# Show the message flow
echo -e "${GREEN}Showing Debezium logs...${NC}"
docker compose logs --tail=20 debezium

echo -e "${GREEN}Showing RabbitMQ messages...${NC}"
echo "Check RabbitMQ management UI at http://localhost:15672 (guest/guest)"

echo -e "${GREEN}Showing Go consumer logs...${NC}"
docker compose logs --tail=20 go-consumer

echo -e "${YELLOW}Checking MongoDB data...${NC}"
echo "To check MongoDB data, run:"
echo "docker exec -it mongodb1 mongosh -u admin -p admin --eval 'use cdc_data; db.mysql_customers.find()'"
echo "docker exec -it mongodb2 mongosh -u admin -p admin --eval 'use cdc_data; db.mysql_customers.find()'"

echo -e "${GREEN}Done! The CDC pipeline is now running.${NC}"
echo "Use the following commands to interact with the system:"
echo "- docker compose logs -f [service]  # Follow logs of a specific service"
echo "- docker compose down               # Stop all services"
echo "- docker compose down -v            # Stop all services and remove volumes"
