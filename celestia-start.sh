#!/bin/bash

# Exit on error
set -e

# Store the root directory
ROOT_DIR=$(pwd)

# Function to cleanup processes on exit
cleanup() {
    echo "Cleaning up processes..."
    # Kill celestia-light-node process
    pkill -f "celestia light" || true
    # Kill celestia-server process
    pkill -f "celestia-server" || true
    # Kill any remaining background processes
    jobs -p | xargs kill -9 2>/dev/null || true

    # Cleanup Docker containers
    echo "Cleaning up Docker containers..."
    docker compose down || true
    leftoverContainers=$(docker container ls -a --filter label=com.docker.compose.project=nitro-testnode -q)
    if [ ! -z "$leftoverContainers" ]; then
        docker rm -f $leftoverContainers || true
    fi
}

# Set trap for cleanup on script exit
trap cleanup EXIT INT TERM

# Initialize flags
VALIDATE=false
ANYTRUST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --validate)
            VALIDATE=true
            shift
            ;;
        --anytrust)
            ANYTRUST=true
            shift
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Usage: $0 [--validate] [--anytrust]"
            exit 1
            ;;
    esac
done

# Create logs directory if it doesn't exist and clean previous logs
echo "Cleaning previous logs..."
rm -rf ${ROOT_DIR}/logs
mkdir -p ${ROOT_DIR}/logs

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install Git first."
    exit 1
fi

# Check if just is installed
if ! command -v just &> /dev/null; then
    echo "Just is not installed. Please install Just first."
    exit 1
fi

# Check if go is installed
if ! command -v go &> /dev/null; then
    echo "Go is not installed. Please install Go first."
    exit 1
fi

# Kill any existing celestia processes and docker containers
echo "Checking for existing processes and containers..."
pkill -f "celestia light" || true
pkill -f "celestia-server" || true
docker compose down || true
leftoverContainers=$(docker container ls -a --filter label=com.docker.compose.project=nitro-testnode -q)
if [ ! -z "$leftoverContainers" ]; then
    docker rm -f $leftoverContainers || true
fi
sleep 2  # Give processes time to shut down

# Clone or use existing celestia-node
if [ ! -d "${ROOT_DIR}/celestia-node" ]; then
    echo "Cloning celestia-node repository..."
    git clone https://github.com/celestiaorg/celestia-node.git
else
    echo "Using existing celestia-node repository..."
fi

cd ${ROOT_DIR}/celestia-node

# Start light node in the background with logging
echo "Starting light node..."
make light-arabica-up > ${ROOT_DIR}/logs/light-node.log 2>&1 &
LIGHT_PID=$!

# Give the light node some time to start
echo "Waiting for light node to initialize..."
sleep 30

# Get auth token
echo "Getting auth token..."
AUTH_TOKEN=$(celestia light auth admin --p2p.network arabica)
echo "Auth token obtained: $AUTH_TOKEN"

# Clone or use existing nitro-das-celestia
cd ${ROOT_DIR}
if [ ! -d "nitro-das-celestia" ]; then
    echo "Cloning nitro-das-celestia repository..."
    git clone https://github.com/celestiaorg/nitro-das-celestia.git
else
    echo "Using existing nitro-das-celestia repository..."
fi

cd nitro-das-celestia/cmd
echo "Building celestia-server..."
go build -o celestia-server

# Run celestia-server with logging in background
echo "Starting celestia-server..."
./celestia-server \
    --enable-rpc \
    --celestia.gas-price 0.01 \
    --celestia.gas-multiplier 1.01 \
    --celestia.namespace-id "000008e5f679bf7116cb" \
    --celestia.rpc "http://localhost:26658" \
    --celestia.auth-token "${AUTH_TOKEN}" \
    --rpc-port 9875 > ${ROOT_DIR}/logs/celestia-server.log 2>&1 &
SERVER_PID=$!

# Wait for celestia-server to initialize
echo "Waiting for celestia-server to initialize..."
sleep 30

# Build testnode command with optional flags
TESTNODE_CMD="./test-node.bash --init-force --dev"
if $VALIDATE; then
    TESTNODE_CMD="$TESTNODE_CMD --validate"
fi
if $ANYTRUST; then
    TESTNODE_CMD="$TESTNODE_CMD --l2-anytrust"
fi

# Change to the root directory to run test-node.bash
cd ${ROOT_DIR}
echo "Starting Arbitrum test node with command: $TESTNODE_CMD"
chmod +x test-node.bash

# Run the command
$TESTNODE_CMD

# Keep the script running
wait