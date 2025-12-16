# Docker Compose Deployment Guide

This guide explains how to deploy the OpenAI Proxy with all required services using Docker Compose with GPU acceleration.

## Overview

The Docker Compose setup includes:
- **HAProxy**: Routes requests to appropriate services
- **Whisper** (faster-whisper-server): Audio transcription with GPU acceleration
- **Ollama**: Large Language Model inference with GPU acceleration
- **Kokoro-FastAPI**: Text-to-Speech with GPU acceleration

All services communicate via a Docker network and utilize NVIDIA GPU for optimal performance.

## Prerequisites

### 1. Docker & Docker Compose
Install Docker and Docker Compose on your system:
- [Docker Installation Guide](https://docs.docker.com/engine/install/)
- [Docker Compose Installation](https://docs.docker.com/compose/install/)

### 2. NVIDIA GPU & Drivers
- NVIDIA GPU with Compute Capability 3.5+ (e.g., GTX 1060, RTX series)
- Latest NVIDIA drivers installed
  ```bash
  # Check your GPU and driver version
  nvidia-smi
  ```

### 3. NVIDIA Container Toolkit
Install the NVIDIA Container Toolkit to enable GPU access in Docker containers:

**Ubuntu/Debian:**
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

**Configure Docker to use NVIDIA runtime:**
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**Verify GPU access in Docker:**
```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

## Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/St5mesh/openai-proxy.git
cd openai-proxy
```

### 2. Configure Environment (Optional)
Copy the example environment file and customize if needed:
```bash
cp .env.example .env
# Edit .env with your preferred settings
```

Default ports:
- HAProxy: `2020`
- Whisper: `8000` (internal)
- Ollama: `11434` (internal)
- TTS: `8880` (internal)

### 3. Start All Services
```bash
docker compose up -d
```

This will:
- Pull all required Docker images
- Create Docker volumes for model storage
- Start all services with GPU acceleration
- Configure networking between services

### 4. Monitor Startup
Watch the logs to see when services are ready:
```bash
docker compose logs -f
```

First startup will take longer as models are downloaded:
- Whisper: Downloads the faster-whisper model (~3GB)
- Ollama: Ready immediately, models pulled on first use
- TTS: Downloads Kokoro TTS models (~500MB)

### 5. Pull an Ollama Model
Ollama doesn't come with models pre-installed. Pull a model:
```bash
# Pull a small model for testing
docker compose exec ollama ollama pull llama2

# Or pull a larger, more capable model
docker compose exec ollama ollama pull llama3.1:8b
```

Available models: https://ollama.com/library

### 6. Verify Services
Check that all services are running:
```bash
docker compose ps
```

All services should show as "Up" and healthy.

Test the proxy health endpoint:
```bash
curl http://localhost:2020/health
# Should return: healthy
```

### 7. Configure Your Client
Set the OpenAI base URL in your client application:
```bash
export OPENAI_BASE_URL=http://localhost:2020/v1
export OPENAI_API_BASE=http://localhost:2020/v1
```

### 8. Test the Endpoints (Optional)
If you have the test script, you can verify all endpoints:
```bash
export OPENAI_API_KEY=dummy  # Not needed for local services
./bin/test-endpoints
```

## Usage Examples

### Chat Completion
```bash
curl http://localhost:2020/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama2",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Text-to-Speech
```bash
curl http://localhost:2020/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Hello, this is a test.",
    "voice": "af_alloy"
  }' \
  --output speech.mp3
```

### Audio Transcription
```bash
curl http://localhost:2020/v1/audio/transcriptions \
  -H "Content-Type: multipart/form-data" \
  -F file="@/path/to/audio.mp3" \
  -F model="whisper-1"
```

## Service Management

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f ollama
docker compose logs -f whisper
docker compose logs -f tts
docker compose logs -f openai-proxy
```

### Restart Services
```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart ollama
```

### Stop Services
```bash
docker compose down
```

### Stop and Remove Volumes (Clean Slate)
```bash
docker compose down -v
```
⚠️ Warning: This will delete all downloaded models!

## GPU Monitoring

Monitor GPU usage while services are running:
```bash
watch -n 1 nvidia-smi
```

You should see the Docker containers utilizing GPU memory and compute when processing requests.

## Customization

### Change Whisper Model
Edit `.env` file:
```bash
# Options: tiny, base, small, medium, large-v2, large-v3
WHISPER_MODEL=Systran/faster-whisper-medium
```

Then restart:
```bash
docker compose down
docker compose up -d
```

### Change Ports
Edit `.env` file to change exposed ports:
```bash
PROXY_PORT=3000
WHISPER_PORT=8001
OLLAMA_PORT=11435
TTS_PORT=8881
```

### Use Different Services
To use OpenAI's services for specific endpoints instead of local ones, modify `openai-proxy-docker.cfg` to uncomment the OpenAI backends and restart the proxy.

## Troubleshooting

### GPU Not Detected
```bash
# Verify NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

# Check Docker daemon configuration
cat /etc/docker/daemon.json
```

### Service Not Starting
```bash
# Check logs for specific service
docker compose logs whisper
docker compose logs ollama
docker compose logs tts

# Check if port is already in use
sudo netstat -tlnp | grep :2020
```

### Out of Memory Errors
- Reduce Whisper model size (use `tiny` or `small`)
- Reduce number of concurrent services
- Check GPU memory: `nvidia-smi`

### Models Not Loading
```bash
# Check volume mounts
docker compose exec ollama ls -la /root/.ollama
docker compose exec whisper ls -la /root/.cache/huggingface
docker compose exec tts ls -la /app/api/src/models

# Manually pull Ollama model
docker compose exec ollama ollama pull llama2
```

### Slow Performance
- Ensure GPU is being used (check `nvidia-smi`)
- Check Docker logs for errors
- Verify NVIDIA drivers are up to date
- Some models are large and may be slow on older GPUs

## Volume Locations

Models are stored in Docker volumes:
- `whisper-models`: Whisper model cache
- `ollama-models`: Ollama models and configuration
- `tts-models`: Kokoro TTS models

To inspect volumes:
```bash
docker volume ls
docker volume inspect openai-proxy_whisper-models
```

## Architecture

```
┌─────────────┐
│   Client    │
│   (Your     │
│   App/Tool) │
└──────┬──────┘
       │ OPENAI_BASE_URL=http://localhost:2020/v1
       ▼
┌─────────────────────────────────────────┐
│           HAProxy (Port 2020)           │
│         Docker: openai-proxy            │
└────┬───────────┬──────────┬─────────────┘
     │           │          │
     │ /v1/audio/│/v1/chat/ │ /v1/audio/
     │transcriptions completions speech
     ▼           ▼          ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Whisper │ │ Ollama  │ │   TTS   │
│ (GPU)   │ │ (GPU)   │ │ (GPU)   │
│Port 8000│ │Port 11434│ │Port 8880│
└─────────┘ └─────────┘ └─────────┘
```

## Advanced Configuration

### CPU-Only Mode
If you don't have an NVIDIA GPU, you can modify `docker-compose.yml`:

1. Remove all `deploy.resources.reservations.devices` sections
2. Use CPU-only images:
   - Whisper: `fedirz/faster-whisper-server:latest-cpu`
   - Kokoro: `ghcr.io/remsky/kokoro-fastapi-cpu:latest`
   - Ollama: Works on CPU by default (will be slower)

### Multi-GPU Setup
To use specific GPUs, modify the `docker-compose.yml`:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ['0', '1']  # Use GPUs 0 and 1
          capabilities: [gpu]
```

## Performance Notes

### Expected Speed (with RTX 3080):
- **Whisper transcription**: ~10-30x faster than real-time
- **Ollama (llama2)**: ~50-100 tokens/second
- **TTS**: ~1-2 seconds for a short sentence

### Memory Usage:
- **Whisper large-v3**: ~3GB VRAM
- **Ollama llama2**: ~4GB VRAM
- **Kokoro TTS**: ~2GB VRAM

Total: ~9GB VRAM for all services running simultaneously.

## Support

For issues and questions:
- GitHub Issues: https://github.com/St5mesh/openai-proxy/issues
- Check service-specific documentation:
  - [Ollama Docs](https://github.com/ollama/ollama)
  - [Faster Whisper Server](https://github.com/fedirz/faster-whisper-server)
  - [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
