#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo -e "${RED}No .env file found. Please run ./run.sh first.${NC}"
  exit 1
fi

# Function to check if a source is enabled
is_enabled() {
  local var_name="ENABLE_$1"
  local value=${!var_name}
  if [[ "$value" == "true" ]]; then
    return 0
  else
    return 1
  fi
}

echo -e "${GREEN}Starting Debezium CDC Pipeline Test...${NC}"

# Clean up existing containers and volumes
echo -e "${YELLOW}Stopping and removing existing containers...${NC}"
docker compose down -v

# Set up the profiles to use based on what's enabled
PROFILES=""
if is_enabled "MYSQL"; then
    PROFILES="$PROFILES mysql"
fi
if is_enabled "POSTGRESQL"; then
    PROFILES="$PROFILES postgresql"
fi
if is_enabled "MONGODB_SOURCE"; then
    PROFILES="$PROFILES mongodb-source"
fi
if is_enabled "ORACLE"; then
    PROFILES="$PROFILES oracle"
fi
if is_enabled "CASSANDRA"; then
    PROFILES="$PROFILES cassandra"
fi

# Start all services
echo -e "${YELLOW}Starting all services with profiles: $PROFILES${NC}"
docker compose --profile $PROFILES up -d

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

# Check source databases
if is_enabled "MYSQL"; then
    echo -e "${YELLOW}Checking MySQL source status...${NC}"
    if docker compose ps | grep mysql | grep -q "Up"; then
        echo -e "${GREEN}✓ MySQL source is running!${NC}"
    else
        echo -e "${RED}✗ MySQL source is not running. Check logs with 'docker compose logs mysql'${NC}"
    fi
fi

if is_enabled "POSTGRESQL"; then
    echo -e "${YELLOW}Checking PostgreSQL source status...${NC}"
    if docker compose ps | grep postgresql | grep -q "Up"; then
        echo -e "${GREEN}✓ PostgreSQL source is running!${NC}"
    else
        echo -e "${RED}✗ PostgreSQL source is not running. Check logs with 'docker compose logs postgresql'${NC}"
    fi
fi

if is_enabled "MONGODB_SOURCE"; then
    echo -e "${YELLOW}Checking MongoDB source status...${NC}"
    if docker compose ps | grep mongodb-source | grep -q "Up"; then
        echo -e "${GREEN}✓ MongoDB source is running!${NC}"
    else
        echo -e "${RED}✗ MongoDB source is not running. Check logs with 'docker compose logs mongodb-source'${NC}"
    fi
fi

if is_enabled "ORACLE"; then
    echo -e "${YELLOW}Checking Oracle source status...${NC}"
    if docker compose ps | grep oracle | grep -q "Up"; then
        echo -e "${GREEN}✓ Oracle source is running!${NC}"
    else
        echo -e "${RED}✗ Oracle source is not running. Check logs with 'docker compose logs oracle'${NC}"
    fi
fi

if is_enabled "CASSANDRA"; then
    echo -e "${YELLOW}Checking Cassandra source status...${NC}"
    if docker compose ps | grep cassandra | grep -q "Up"; then
        echo -e "${GREEN}✓ Cassandra source is running!${NC}"
    else
        echo -e "${RED}✗ Cassandra source is not running. Check logs with 'docker compose logs cassandra'${NC}"
    fi
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
docker compose --profile $PROFILES up --build data-generator

# Show recent logs
echo -e "${GREEN}Recent logs from Debezium:${NC}"
docker compose logs --tail=20 debezium

# Check MongoDB sink collections based on source
COLLECTION_PREFIX="${MONGODB_SINK_COLLECTION_PREFIX}"
case "${SOURCE_TYPE}" in
    mysql)
        COLLECTION_PREFIX="mysql"
        ;;
    postgresql)
        COLLECTION_PREFIX="postgresql"
        ;;
    mongodb)
        COLLECTION_PREFIX="mongodb"
        ;;
    oracle)
        COLLECTION_PREFIX="oracle"
        ;;
    cassandra)
        COLLECTION_PREFIX="cassandra"
        ;;
esac

echo -e "${GREEN}Checking MongoDB sinks for ${COLLECTION_PREFIX} collections:${NC}"
echo "mongodb1:"
docker exec -it mongodb1 mongosh -u ${MONGODB_SINK_USER} -p ${MONGODB_SINK_PASSWORD} --eval "use ${MONGODB_SINK_DATABASE}; db.getCollectionNames().filter(c => c.startsWith('${COLLECTION_PREFIX}'))"
echo "mongodb2:"
docker exec -it mongodb2 mongosh -u ${MONGODB_SINK_USER} -p ${MONGODB_SINK_PASSWORD} --eval "use ${MONGODB_SINK_DATABASE}; db.getCollectionNames().filter(c => c.startsWith('${COLLECTION_PREFIX}'))"

echo -e "${GREEN}Recent logs from Go consumer:${NC}"
docker compose logs --tail=20 go-consumer

echo -e "${GREEN}Test completed.${NC}"
echo "To see all logs, run:"
echo "docker compose logs"
echo "To see specific service logs, run:"
echo "docker compose logs [service-name]"
echo "To check data in MongoDB sinks, run:"
echo "docker exec -it mongodb1 mongosh -u ${MONGODB_SINK_USER} -p ${MONGODB_SINK_PASSWORD} --eval 'use ${MONGODB_SINK_DATABASE}; db.${COLLECTION_PREFIX}_customers.find()'"
