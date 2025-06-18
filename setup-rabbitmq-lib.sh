#!/bin/bash

# Script to install RabbitMQ client library to Debezium server
echo "Installing RabbitMQ client library to Debezium server..."

# Create a temporary container to download the required JARs
docker run --rm -v "$(pwd)/debezium-server/lib:/app" --name rabbitmq-lib-downloader \
  alpine:latest sh -c "
    apk add --no-cache wget && 
    mkdir -p /app && 
    cd /app && 
    wget https://repo1.maven.org/maven2/com/rabbitmq/amqp-client/5.19.0/amqp-client-5.19.0.jar && 
    wget https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar && 
    echo 'RabbitMQ libraries downloaded successfully'
  "

# Now copy the JARs to the Debezium container
echo "Waiting for Debezium container to be ready..."
sleep 5

docker cp debezium-server/lib/amqp-client-5.19.0.jar debezium:/debezium/lib/
docker cp debezium-server/lib/slf4j-api-2.0.9.jar debezium:/debezium/lib/

# Restart the Debezium container
echo "Restarting Debezium container..."
docker restart debezium

echo "Setup complete."
