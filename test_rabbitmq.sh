#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Testing RabbitMQ Configuration...${NC}"

# Clean up existing containers and volumes
echo -e "${YELLOW}Stopping and removing existing containers...${NC}"
docker compose down -v

# Start RabbitMQ only
echo -e "${YELLOW}Starting RabbitMQ container...${NC}"
docker compose up -d rabbitmq

# Wait for RabbitMQ to start
echo -e "${YELLOW}Waiting for RabbitMQ to start...${NC}"
sleep 10

# Check if RabbitMQ is running
echo -e "${GREEN}Checking RabbitMQ status...${NC}"
if docker compose ps | grep rabbitmq | grep -q "Up"; then
    echo -e "${GREEN}✓ RabbitMQ is running!${NC}"
    
    # Check if management UI is accessible
    echo -e "${YELLOW}Checking RabbitMQ management UI...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:15672/ | grep -q "200"; then
        echo -e "${GREEN}✓ RabbitMQ management UI is accessible!${NC}"
    else
        echo -e "${RED}✗ RabbitMQ management UI is not accessible.${NC}"
    fi
    
    # Check if admin user can authenticate
    echo -e "${YELLOW}Testing admin user authentication...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" -u admin:admin http://localhost:15672/api/whoami | grep -q "200"; then
        echo -e "${GREEN}✓ Admin user authentication successful!${NC}"
    else
        echo -e "${RED}✗ Admin user authentication failed.${NC}"
    fi
    
    # Show RabbitMQ logs
    echo -e "${YELLOW}RabbitMQ logs:${NC}"
    docker compose logs rabbitmq | tail -n 20
else
    echo -e "${RED}✗ RabbitMQ is not running. Showing logs:${NC}"
    docker compose logs rabbitmq
fi

echo -e "${GREEN}Test completed.${NC}"
