#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Debezium CDC Pipeline...${NC}"

# Clean up existing containers and volumes
echo -e "${YELLOW}Stopping and removing existing containers...${NC}"
docker compose down -v

# Start all services
echo -e "${YELLOW}Starting all services...${NC}"
docker compose up -d

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 30

# Check all services
echo -e "${GREEN}Checking all services...${NC}"
docker compose ps

# Check RabbitMQ
echo -e "${YELLOW}Checking RabbitMQ status...${NC}"
if docker compose ps | grep rabbitmq | grep -q "Up"; then
    echo -e "${GREEN}✓ RabbitMQ is running!${NC}"
else
    echo -e "${RED}✗ RabbitMQ is not running. Check logs with 'docker compose logs rabbitmq'${NC}"
fi

# Check Debezium
echo -e "${YELLOW}Checking Debezium status...${NC}"
if docker compose ps | grep debezium | grep -q "Up"; then
    echo -e "${GREEN}✓ Debezium is running!${NC}"
    
    # Check Debezium logs for RabbitMQ connection
    echo -e "${YELLOW}Checking Debezium-RabbitMQ connection...${NC}"
    if docker compose logs debezium | grep -q "RabbitMQ"; then
        echo -e "${GREEN}✓ Debezium RabbitMQ connection found in logs!${NC}"
    else
        echo -e "${YELLOW}⚠ No RabbitMQ connection info found in Debezium logs. Check more detailed logs.${NC}"
    fi
else
    echo -e "${RED}✗ Debezium is not running. Check logs with 'docker compose logs debezium'${NC}"
fi

# Check Go consumer
echo -e "${YELLOW}Checking Go consumer status...${NC}"
if docker compose ps | grep go-consumer | grep -q "Up"; then
    echo -e "${GREEN}✓ Go consumer is running!${NC}"
else
    echo -e "${RED}✗ Go consumer is not running. Check logs with 'docker compose logs go-consumer'${NC}"
fi

# Generate some test data
echo -e "${YELLOW}Generating test data...${NC}"
docker compose up --build data-generator

# Show recent logs
echo -e "${GREEN}Recent logs from Debezium:${NC}"
docker compose logs --tail=20 debezium

echo -e "${GREEN}Recent logs from Go consumer:${NC}"
docker compose logs --tail=20 go-consumer

echo -e "${YELLOW}Testing Debezium Monitoring Endpoints:${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/q/health | grep -q "200"; then
    echo -e "${GREEN}✓ Debezium health endpoint is accessible!${NC}"
    echo "Health UI: http://localhost:8080/q/health-ui"
    echo "Metrics: http://localhost:8080/q/metrics"
else
    echo -e "${RED}✗ Debezium monitoring endpoints are not accessible.${NC}"
fi

echo -e "${GREEN}Test completed.${NC}"
echo "To see all logs, run:"
echo "docker compose logs"
echo "To see specific service logs, run:"
echo "docker compose logs [service-name]"
