FROM quay.io/debezium/server:3.0.0.Final

# Add RabbitMQ sink connector
USER root
RUN microdnf -y install unzip curl wget

# Ensure we have the RabbitMQ dependencies
RUN mkdir -p /tmp/deps && \
    cd /tmp/deps && \
    wget https://repo1.maven.org/maven2/com/rabbitmq/amqp-client/5.19.0/amqp-client-5.19.0.jar && \
    wget https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.9/slf4j-api-2.0.9.jar && \
    wget https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/2.0.9/slf4j-simple-2.0.9.jar && \
    cp *.jar /debezium/lib/ && \
    cd / && \
    rm -rf /tmp/deps

# Install netcat and ping for debugging
RUN microdnf -y install iputils nc

# Show installed JARs for debugging
RUN ls -la /debezium/lib/

USER jboss

# Configuration will be mounted from host
WORKDIR /debezium
