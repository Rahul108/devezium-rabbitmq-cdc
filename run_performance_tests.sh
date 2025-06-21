#!/bin/bash

# Performance test scenarios for the high-throughput data generator
# This script runs multiple test scenarios to validate different performance levels

set -e

echo "🎯 High-Throughput CDC Performance Test Suite"
echo "=============================================="

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Test scenarios
declare -a scenarios=(
    "1000 30 10"    # 1K CPS, 30s, 10 workers - Warm-up test
    "5000 60 25"    # 5K CPS, 60s, 25 workers - Medium load
    "10000 60 50"   # 10K CPS, 60s, 50 workers - Target load
    "15000 30 75"   # 15K CPS, 30s, 75 workers - Stress test
)

# Function to run a test scenario
run_scenario() {
    local cps=$1
    local duration=$2
    local concurrency=$3
    
    echo ""
    echo "🚀 Running scenario: ${cps} CPS, ${duration}s duration, ${concurrency} workers"
    echo "================================================================"
    
    # Run the test
    ./run_high_throughput_test.sh $cps $duration $concurrency
    
    echo "✅ Scenario completed"
    echo ""
    echo "⏳ Waiting 30 seconds before next test..."
    sleep 30
}

# Function to show pre-test status
show_status() {
    echo "📊 Pre-test system status:"
    echo "=========================="
    
    # Check if services are running
    echo "Services status:"
    docker compose ps | grep -E "(mysql|rabbitmq|debezium|mongo)"
    
    echo ""
    echo "RabbitMQ queue status:"
    docker compose exec rabbitmq rabbitmqctl list_queues name messages 2>/dev/null || echo "RabbitMQ not ready"
    
    echo ""
}

# Function to collect final metrics
collect_metrics() {
    echo ""
    echo "📈 Final Test Metrics"
    echo "===================="
    
    echo "RabbitMQ queue status:"
    docker compose exec rabbitmq rabbitmqctl list_queues name messages consumers 2>/dev/null || echo "RabbitMQ not accessible"
    
    echo ""
    echo "MongoDB collections:"
    docker compose exec mongodb1 mongosh --quiet --eval "
        db = db.getSiblingDB('cdc_data');
        db.runCommand('listCollections').cursor.firstBatch.forEach(c => {
            const count = db[c.name].countDocuments();
            print(c.name + ': ' + count + ' documents');
        });
    " 2>/dev/null || echo "MongoDB not accessible"
    
    echo ""
}

# Main execution
main() {
    echo "Starting performance test suite..."
    echo "Each test will run for the specified duration."
    echo "Press Ctrl+C to abort the test suite."
    echo ""
    
    # Show initial status
    show_status
    
    # Ask for confirmation
    read -p "Proceed with the test suite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Test suite aborted."
        exit 0
    fi
    
    # Run scenarios
    for scenario in "${scenarios[@]}"; do
        # Parse scenario parameters
        IFS=' ' read -r cps duration concurrency <<< "$scenario"
        run_scenario $cps $duration $concurrency
    done
    
    # Collect final metrics
    collect_metrics
    
    echo "🎉 Performance test suite completed!"
    echo ""
    echo "📋 Summary:"
    echo "- Tested scenarios: ${#scenarios[@]}"
    echo "- Check individual logs for detailed metrics"
    echo "- RabbitMQ Management UI: http://localhost:15672"
    echo ""
}

# Handle interruption
trap 'echo -e "\n\n⚠️  Test suite interrupted by user"; exit 130' INT

# Run main function
main "$@"
