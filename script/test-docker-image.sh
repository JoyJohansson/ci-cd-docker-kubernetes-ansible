#!/bin/bash
# Test script for Docker image with improved error handling and cleanup
# Place this file in scripts/test-docker-image.sh

# Exit immediately if any command fails
set -e

# Get parameters from environment or use defaults
CONTAINER_NAME=${CONTAINER_NAME:-"test-nginx"}
IMAGE_NAME=${IMAGE_NAME:-"my-nginx:latest"}
HOST_PORT=${HOST_PORT:-8080}
CONTAINER_PORT=${CONTAINER_PORT:-80}
EXPECTED_CONTENT=${EXPECTED_CONTENT:-"CI/CD Test - Fruity Edition"}

echo "=== Docker Image Test Script ==="
echo "Testing image: $IMAGE_NAME"
echo "Container name: $CONTAINER_NAME"
echo "Port mapping: $HOST_PORT:$CONTAINER_PORT"

# Function to ensure cleanup on exit
cleanup() {
  echo "Cleaning up resources..."
  docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
  echo "Cleanup complete"
}

# Set trap to ensure cleanup even on failure
trap cleanup EXIT

# Start the container for testing
echo "Starting container for testing..."
docker run -d --name $CONTAINER_NAME -p $HOST_PORT:$CONTAINER_PORT $IMAGE_NAME

# Give it a moment to initialize
echo "Waiting for container to initialize..."
sleep 3

# Test 1: Use docker inspect to verify container is running
echo "Verifying container status..."
if ! docker inspect -f '{{.State.Running}}' $CONTAINER_NAME | grep -q "true"; then
  echo "ERROR: Container is not running!"
  docker logs $CONTAINER_NAME
  exit 1
fi
echo "✅ Container is running correctly"

# Test 2: Check HTTP response with curl --fail
echo "Testing HTTP response..."
if ! curl --fail --silent --max-time 5 http://localhost:$HOST_PORT > /dev/null; then
  echo "ERROR: Server did not respond with successful HTTP status!"
  docker logs $CONTAINER_NAME
  exit 1
fi
echo "✅ HTTP response check passed"

# Test 3: Verify content matches expected
echo "Verifying content..."
ACTUAL_CONTENT=$(curl -s http://localhost:$HOST_PORT)
if [[ "$ACTUAL_CONTENT" != *"$EXPECTED_CONTENT"* ]]; then
  echo "ERROR: Content verification failed!"
  echo "Expected to find: $EXPECTED_CONTENT"
  echo "Actual content: $ACTUAL_CONTENT"
  exit 1
fi
echo "✅ Content verification passed"

# Test 4: Verify 404 handling
echo "Testing 404 handling..."
ERROR_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$HOST_PORT/notfound)
if [ "$ERROR_RESPONSE" -ne 404 ]; then
  echo "ERROR: Server did not return 404 for non-existent page!"
  echo "Received status code: $ERROR_RESPONSE"
  exit 1
fi
echo "✅ 404 handling check passed"

echo "🎉 All tests passed successfully!"