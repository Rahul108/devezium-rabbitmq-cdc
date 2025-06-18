#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables if available
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo -e "${YELLOW}No .env file found. Using default values...${NC}"
  RABBITMQ_USER="guest"
  RABBITMQ_PASSWORD="guest"
  RABBITMQ_MANAGEMENT_PORT="15672"
  RABBITMQ_EXCHANGE="cdc-events"
  RABBITMQ_QUEUE_NAME="cdc.events"
  RABBITMQ_ROUTING_KEY="cdc"
fi

echo -e "${GREEN}Testing RabbitMQ Configuration...${NC}"

# Clean up existing containers and volumes
echo -e "${YELLOW}Stopping and removing existing containers...${NC}"
docker compose down rabbitmq

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
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:${RABBITMQ_MANAGEMENT_PORT}/ | grep -q "200"; then
        echo -e "${GREEN}✓ RabbitMQ management UI is accessible!${NC}"
    else
        echo -e "${RED}✗ RabbitMQ management UI is not accessible.${NC}"
    fi
    
    # Check if admin user can authenticate
    echo -e "${YELLOW}Testing user authentication...${NC}"
    if curl -s -o /dev/null -w "%{http_code}" -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} http://localhost:${RABBITMQ_MANAGEMENT_PORT}/api/whoami | grep -q "200"; then
        echo -e "${GREEN}✓ User authentication successful!${NC}"
        
        # Check exchange existence
        echo -e "${YELLOW}Checking RabbitMQ exchange '${RABBITMQ_EXCHANGE}'...${NC}"
        EXCHANGE_RESPONSE=$(curl -s -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} http://localhost:${RABBITMQ_MANAGEMENT_PORT}/api/exchanges/%2F/${RABBITMQ_EXCHANGE})
        if [[ "$EXCHANGE_RESPONSE" == *"resource_type"* ]]; then
            echo -e "${GREEN}✓ Exchange '${RABBITMQ_EXCHANGE}' exists${NC}"
            
            # Extract exchange type
            EXCHANGE_TYPE=$(echo $EXCHANGE_RESPONSE | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
            echo -e "${GREEN}  Exchange type: $EXCHANGE_TYPE${NC}"
        else
            echo -e "${YELLOW}⚠ Exchange '${RABBITMQ_EXCHANGE}' does not exist yet. Will be created by Debezium.${NC}"
        fi
        
        # Check queue existence
        echo -e "${YELLOW}Checking RabbitMQ queue '${RABBITMQ_QUEUE_NAME}'...${NC}"
        QUEUE_RESPONSE=$(curl -s -u ${RABBITMQ_USER}:${RABBITMQ_PASSWORD} http://localhost:${RABBITMQ_MANAGEMENT_PORT}/api/queues/%2F/${RABBITMQ_QUEUE_NAME})
        if [[ "$QUEUE_RESPONSE" == *"message_stats"* ]] || [[ "$QUEUE_RESPONSE" == *"consumer_details"* ]]; then
            echo -e "${GREEN}✓ Queue '${RABBITMQ_QUEUE_NAME}' exists${NC}"
            
            # Extract message count
            MESSAGE_COUNT=$(echo $QUEUE_RESPONSE | grep -o '"messages":[0-9]*' | cut -d':' -f2)
            echo -e "${GREEN}  Queue message count: $MESSAGE_COUNT${NC}"
            
            # Extract consumer count
            CONSUMER_COUNT=$(echo $QUEUE_RESPONSE | grep -o '"consumers":[0-9]*' | cut -d':' -f2)
            echo -e "${GREEN}  Queue consumer count: $CONSUMER_COUNT${NC}"
        else
            echo -e "${YELLOW}⚠ Queue '${RABBITMQ_QUEUE_NAME}' does not exist yet. Will be created by go-consumer.${NC}"
            
            # Create queue and bindings
            echo -e "${YELLOW}Creating queue and bindings...${NC}"
            docker exec rabbitmq rabbitmqadmin -u ${RABBITMQ_USER} -p ${RABBITMQ_PASSWORD} declare queue name=${RABBITMQ_QUEUE_NAME} durable=true
            
            # Create exchange if needed
            if [[ "$EXCHANGE_RESPONSE" != *"resource_type"* ]]; then
                docker exec rabbitmq rabbitmqadmin -u ${RABBITMQ_USER} -p ${RABBITMQ_PASSWORD} declare exchange name=${RABBITMQ_EXCHANGE} type=topic durable=true
            fi
            
            # Create binding
            docker exec rabbitmq rabbitmqadmin -u ${RABBITMQ_USER} -p ${RABBITMQ_PASSWORD} declare binding source=${RABBITMQ_EXCHANGE} destination=${RABBITMQ_QUEUE_NAME} routing_key=${RABBITMQ_ROUTING_KEY}
            
            echo -e "${GREEN}✓ Queue and bindings created${NC}"
        fi
        
        # Publish a test message
        echo -e "${YELLOW}Publishing a test message to RabbitMQ...${NC}"
        TEST_MESSAGE='{"test":"message","timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}'
        docker exec rabbitmq rabbitmqadmin -u ${RABBITMQ_USER} -p ${RABBITMQ_PASSWORD} publish exchange=${RABBITMQ_EXCHANGE} routing_key=${RABBITMQ_ROUTING_KEY} payload="$TEST_MESSAGE"
        echo -e "${GREEN}✓ Test message published${NC}"
        
    else
        echo -e "${RED}✗ User authentication failed.${NC}"
    fi
    
    # Show RabbitMQ logs
    echo -e "${YELLOW}RabbitMQ logs:${NC}"
    docker compose logs rabbitmq | tail -n 20
else
    echo -e "${RED}✗ RabbitMQ is not running. Showing logs:${NC}"
    docker compose logs rabbitmq
fi

echo -e "${GREEN}Test completed.${NC}"
echo "Check the RabbitMQ Management UI at http://localhost:${RABBITMQ_MANAGEMENT_PORT}"
echo "Username: ${RABBITMQ_USER}"
echo "Password: ${RABBITMQ_PASSWORD}"
