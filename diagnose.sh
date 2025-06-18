#!/bin/bash

echo "Collecting diagnostics for Debezium and RabbitMQ..."

# Get container IDs and network info
echo "==== Docker Container Information ===="
docker ps -a
echo ""

echo "==== Network Information ===="
docker network inspect debezium-network
echo ""

echo "==== RabbitMQ Status ===="
docker exec rabbitmq rabbitmqctl status | grep -A 5 "Listeners"
echo ""

echo "==== Debezium Environment ===="
docker exec debezium env | grep -E "RABBIT|DEBEZIUM"
echo ""

echo "==== Checking RabbitMQ Connection from Debezium ===="
docker exec debezium bash -c "ping -c 3 rabbitmq"
docker exec debezium bash -c "nc -zv rabbitmq 5672 || echo 'Connection failed'"
echo ""

echo "==== RabbitMQ Logs ===="
docker compose logs --tail=30 rabbitmq
echo ""

echo "==== Debezium Logs ===="
docker compose logs --tail=50 debezium
echo ""

echo "==== Checking RabbitMQ libraries in Debezium ===="
docker exec debezium bash -c "ls -la /debezium/lib/ | grep -E 'amqp|rabbit'"
echo ""

echo "==== Diagnostics Complete ===="
echo "To manually test connection from debezium container:"
echo "docker exec -it debezium bash"
echo "nc -zv rabbitmq 5672"
