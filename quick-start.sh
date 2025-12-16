#!/usr/bin/env bash
set -o nounset -o pipefail -o errexit

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OpenAI Proxy - Quick Start Script    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not available${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | head -n 1
    
    # Check for NVIDIA Container Toolkit
    if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ NVIDIA Container Toolkit is configured${NC}"
    else
        echo -e "${YELLOW}⚠ NVIDIA Container Toolkit may not be configured properly${NC}"
        echo "See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⚠ No NVIDIA GPU detected${NC}"
    echo "The services will run on CPU, which will be slower."
    echo "For GPU acceleration, install NVIDIA drivers and NVIDIA Container Toolkit."
    echo ""
    read -p "Continue with CPU-only mode? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Starting services...${NC}"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from .env.example${NC}"
    cp .env.example .env
fi

# Start services
docker compose up -d

echo ""
echo -e "${GREEN}✓ Services started${NC}"
echo ""
echo -e "${BLUE}Waiting for services to be ready...${NC}"

# Wait for services to be healthy
max_wait=120
elapsed=0
while [ $elapsed -lt $max_wait ]; do
    if docker compose ps | grep -q "healthy"; then
        sleep 5
        echo -e "${GREEN}✓ Services are healthy${NC}"
        break
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $max_wait ]; then
    echo ""
    echo -e "${YELLOW}⚠ Services are taking longer than expected to start${NC}"
    echo "This is normal on first run as models need to be downloaded."
    echo "You can check the logs with: docker compose logs -f"
fi

echo ""
echo -e "${BLUE}Checking if Ollama has models...${NC}"

# Check if Ollama has any models
if docker compose exec -T ollama ollama list 2>/dev/null | grep -q "NAME"; then
    echo -e "${GREEN}✓ Ollama models are already installed${NC}"
else
    echo -e "${YELLOW}No Ollama models found. Pulling llama2...${NC}"
    docker compose exec -T ollama ollama pull llama2
    echo -e "${GREEN}✓ llama2 model installed${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!                      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "The OpenAI Proxy is now running on ${BLUE}http://localhost:2020${NC}"
echo ""
echo -e "${YELLOW}Configure your client:${NC}"
echo "  export OPENAI_BASE_URL=http://localhost:2020/v1"
echo "  export OPENAI_API_BASE=http://localhost:2020/v1"
echo ""
echo -e "${YELLOW}Test the health endpoint:${NC}"
echo "  curl http://localhost:2020/health"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo "  docker compose logs -f"
echo ""
echo -e "${YELLOW}Stop services:${NC}"
echo "  docker compose down"
echo ""
echo -e "For more information, see: ${BLUE}DOCKER_DEPLOYMENT.md${NC}"
echo ""
