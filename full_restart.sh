#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}Stopping all containers...${NC}"
docker compose down

echo -e "${YELLOW}Removing all volumes...${NC}"
docker compose down -v

echo -e "${YELLOW}Removing data directories...${NC}"
rm -rf ./debezium-server/data/* ./rabbitmq/data/* ./mongodb/data1/* ./mongodb/data2/* ./mysql/data/*

echo -e "${GREEN}Rebuilding all containers...${NC}"
docker compose build --no-cache

echo -e "${YELLOW}Starting RabbitMQ first...${NC}"
docker compose up -d rabbitmq
echo -e "${YELLOW}Waiting for RabbitMQ to start (15 seconds)...${NC}"
sleep 15

echo -e "${YELLOW}Starting MySQL...${NC}"
docker compose up -d mysql
echo -e "${YELLOW}Waiting for MySQL to initialize (15 seconds)...${NC}"
sleep 15

echo -e "${YELLOW}Starting MongoDB instances...${NC}"
docker compose up -d mongodb1 mongodb2
echo -e "${YELLOW}Waiting for MongoDB to initialize (10 seconds)...${NC}"
sleep 10

echo -e "${GREEN}Running network connectivity test...${NC}"
./test_rabbitmq.sh

echo -e "${YELLOW}Starting Debezium with verbose logging...${NC}"
docker compose up -d debezium

echo -e "${YELLOW}Waiting for Debezium to initialize (15 seconds)...${NC}"
sleep 15

echo -e "${GREEN}Debezium logs:${NC}"
docker compose logs debezium

echo -e "${YELLOW}Starting Go consumer...${NC}"
docker compose up -d go-consumer

echo -e "${GREEN}Generating test data...${NC}"
docker compose up data-generator

echo -e "${GREEN}All services should now be running. Check logs with:${NC}"
echo "docker compose logs -f debezium"
echo "docker compose logs -f rabbitmq"
echo "docker compose logs -f go-consumer"
