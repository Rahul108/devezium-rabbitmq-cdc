#!/bin/bash

# Script to run and test the Debezium CDC solution with multiple sources

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage information
function show_usage() {
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo "Starts the Debezium CDC stack with the specified source databases"
    echo ""
    echo "Options:"
    echo "  --mysql       Enable MySQL source"
    echo "  --postgresql  Enable PostgreSQL source"
    echo "  --mongodb     Enable MongoDB source"
    echo "  --oracle      Enable Oracle source"
    echo "  --cassandra   Enable Cassandra source"
    echo "  --all         Enable all sources"
    echo "  --clean       Clean all data before starting"
    echo "  --help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --mysql                # Start with MySQL source only"
    echo "  $0 --postgresql --mongodb # Start with PostgreSQL and MongoDB sources"
    echo "  $0 --all                  # Start with all sources"
    exit 1
}

# Default values
MYSQL=true
POSTGRESQL=false
MONGODB=false
ORACLE=false
CASSANDRA=false
CLEAN=false

# Parse command-line arguments
if [ $# -gt 0 ]; then
    # Reset all to false if arguments are provided
    MYSQL=false
    
    while [ "$1" != "" ]; do
        case $1 in
            --mysql)
                MYSQL=true
                ;;
            --postgresql)
                POSTGRESQL=true
                ;;
            --mongodb)
                MONGODB=true
                ;;
            --oracle)
                ORACLE=true
                ;;
            --cassandra)
                CASSANDRA=true
                ;;
            --all)
                MYSQL=true
                POSTGRESQL=true
                MONGODB=true
                ORACLE=true
                CASSANDRA=true
                ;;
            --clean)
                CLEAN=true
                ;;
            --help)
                show_usage
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                ;;
        esac
        shift
    done
fi

# Check if .env.example file exists and use it as template
if [ -f .env.example ]; then
  echo -e "${GREEN}Creating .env file from .env.example template...${NC}"
  cp .env.example .env
elif [ -f .env ]; then
  echo -e "${GREEN}Loading environment variables from existing .env file...${NC}"
else
  echo -e "${RED}No .env or .env.example file found. Please create an .env file before running this script.${NC}"
  exit 1
fi

# Update the .env file with the selected sources
sed -i "s/ENABLE_MYSQL=.*/ENABLE_MYSQL=$MYSQL/" .env
sed -i "s/ENABLE_POSTGRESQL=.*/ENABLE_POSTGRESQL=$POSTGRESQL/" .env
sed -i "s/ENABLE_MONGODB_SOURCE=.*/ENABLE_MONGODB_SOURCE=$MONGODB/" .env
sed -i "s/ENABLE_ORACLE=.*/ENABLE_ORACLE=$ORACLE/" .env
sed -i "s/ENABLE_CASSANDRA=.*/ENABLE_CASSANDRA=$CASSANDRA/" .env

# Set the source type based on what's enabled
if [ "$MYSQL" = "true" ]; then
    sed -i "s/SOURCE_TYPE=.*/SOURCE_TYPE=mysql/" .env
elif [ "$POSTGRESQL" = "true" ]; then
    sed -i "s/SOURCE_TYPE=.*/SOURCE_TYPE=postgresql/" .env
elif [ "$MONGODB" = "true" ]; then
    sed -i "s/SOURCE_TYPE=.*/SOURCE_TYPE=mongodb/" .env
elif [ "$ORACLE" = "true" ]; then
    sed -i "s/SOURCE_TYPE=.*/SOURCE_TYPE=oracle/" .env
elif [ "$CASSANDRA" = "true" ]; then
    sed -i "s/SOURCE_TYPE=.*/SOURCE_TYPE=cassandra/" .env
fi

# Load the updated environment variables
set -a
source .env
set +a

# Clean data directories if requested
if [ "$CLEAN" = "true" ]; then
    echo -e "${YELLOW}Cleaning data directories...${NC}"
    
    # Stop any running containers first
    docker compose down
    
    # Clean MySQL data if enabled
    if [ "$MYSQL" = "true" ]; then
        echo "Cleaning MySQL data..."
        rm -rf ./mysql/data/*
        mkdir -p ./mysql/data
    fi
    
    # Clean PostgreSQL data if enabled
    if [ "$POSTGRESQL" = "true" ]; then
        echo "Cleaning PostgreSQL data..."
        rm -rf ./postgresql/data/*
        mkdir -p ./postgresql/data
    fi
    
    # Clean MongoDB source data if enabled
    if [ "$MONGODB" = "true" ]; then
        echo "Cleaning MongoDB source data..."
        rm -rf ./mongodb-source/data/*
        mkdir -p ./mongodb-source/data
    fi
    
    # Clean Oracle data if enabled
    if [ "$ORACLE" = "true" ]; then
        echo "Cleaning Oracle data..."
        rm -rf ./oracle/data/*
        mkdir -p ./oracle/data
    fi
    
    # Clean Cassandra data if enabled
    if [ "$CASSANDRA" = "true" ]; then
        echo "Cleaning Cassandra data..."
        rm -rf ./cassandra/data/*
        mkdir -p ./cassandra/data
    fi
    
    # Clean sink MongoDB data
    echo "Cleaning sink MongoDB data..."
    rm -rf ./mongodb/data1/* ./mongodb/data2/*
    mkdir -p ./mongodb/data1 ./mongodb/data2
    
    # Clean Debezium data
    echo "Cleaning Debezium data..."
    rm -rf ./debezium-server/data/*
    mkdir -p ./debezium-server/data
    
    # Clean RabbitMQ data
    echo "Cleaning RabbitMQ data..."
    rm -rf ./rabbitmq/data/*
    mkdir -p ./rabbitmq/data
fi

echo -e "${YELLOW}Starting Debezium CDC with the following sources:${NC}"
[ "$MYSQL" = "true" ] && echo -e "${GREEN}- MySQL${NC}"
[ "$POSTGRESQL" = "true" ] && echo -e "${GREEN}- PostgreSQL${NC}"
[ "$MONGODB" = "true" ] && echo -e "${GREEN}- MongoDB${NC}"
[ "$ORACLE" = "true" ] && echo -e "${GREEN}- Oracle${NC}"
[ "$CASSANDRA" = "true" ] && echo -e "${GREEN}- Cassandra${NC}"

# Set up the profiles to use based on what's enabled
PROFILES=""
if [ "$MYSQL" = "true" ]; then
    PROFILES="$PROFILES mysql"
fi
if [ "$POSTGRESQL" = "true" ]; then
    PROFILES="$PROFILES postgresql"
fi
if [ "$MONGODB" = "true" ]; then
    PROFILES="$PROFILES mongodb-source"
fi
if [ "$ORACLE" = "true" ]; then
    PROFILES="$PROFILES oracle"
fi
if [ "$CASSANDRA" = "true" ]; then
    PROFILES="$PROFILES cassandra"
fi

# Build and start all services except the data generator
echo -e "${GREEN}Building and starting services...${NC}"
docker compose --profile $PROFILES up -d --build rabbitmq mongodb1 mongodb2 debezium go-consumer

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 20

# Check if all services are running
echo -e "${GREEN}Checking service status...${NC}"
docker compose ps

# Generate test data
echo -e "${YELLOW}Generating test data...${NC}"
docker compose --profile $PROFILES up --build data-generator

# Show the message flow
echo -e "${GREEN}Showing Debezium logs...${NC}"
docker compose logs --tail=20 debezium

echo -e "${GREEN}Showing RabbitMQ messages...${NC}"
echo "Check RabbitMQ management UI at http://localhost:${RABBITMQ_MANAGEMENT_PORT} (${RABBITMQ_USER}/${RABBITMQ_PASSWORD})"

echo -e "${GREEN}Showing Go consumer logs...${NC}"
docker compose logs --tail=20 go-consumer

echo -e "${YELLOW}Checking MongoDB sink data...${NC}"
echo "To check MongoDB data, run:"
echo "docker exec -it mongodb1 mongosh -u ${MONGODB_SINK_USER} -p ${MONGODB_SINK_PASSWORD} --eval 'use ${MONGODB_SINK_DATABASE}; db.${MONGODB_SINK_COLLECTION_PREFIX}_customers.find()'"
echo "docker exec -it mongodb2 mongosh -u ${MONGODB_SINK_USER} -p ${MONGODB_SINK_PASSWORD} --eval 'use ${MONGODB_SINK_DATABASE}; db.${MONGODB_SINK_COLLECTION_PREFIX}_customers.find()'"

echo -e "${GREEN}Done! The CDC pipeline is now running.${NC}"
echo "Use the following commands to interact with the system:"
echo "- docker compose logs -f [service]  # Follow logs of a specific service"
echo "- docker compose down               # Stop all services"
echo "- docker compose down -v            # Stop all services and remove volumes"
