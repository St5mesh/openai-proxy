.PHONY: help start stop restart logs status pull-models test clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start all services
	@echo "Starting OpenAI Proxy and all services..."
	@docker compose up -d
	@echo "Services started. Use 'make logs' to view logs or 'make status' to check status."

stop: ## Stop all services
	@echo "Stopping all services..."
	@docker compose down
	@echo "Services stopped."

restart: ## Restart all services
	@echo "Restarting all services..."
	@docker compose restart
	@echo "Services restarted."

logs: ## Follow logs from all services
	@docker compose logs -f

status: ## Show status of all services
	@docker compose ps

pull-models: ## Pull default Ollama model (llama2)
	@echo "Pulling llama2 model..."
	@docker compose exec ollama ollama pull llama2
	@echo "Model pulled successfully."

test: ## Run endpoint tests (requires OPENAI_API_KEY)
	@if [ -z "$$OPENAI_API_KEY" ]; then \
		echo "Warning: OPENAI_API_KEY not set. Using dummy key."; \
		export OPENAI_API_KEY=dummy; \
	fi
	@./bin/test-endpoints

clean: ## Stop services and remove volumes (deletes all models)
	@echo "WARNING: This will remove all volumes including downloaded models!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		echo "Services stopped and volumes removed."; \
	else \
		echo "Cancelled."; \
	fi

quick-start: ## Run the quick start script
	@./quick-start.sh

# Docker-specific targets
build: ## Build custom images (if needed in the future)
	@docker compose build

pull: ## Pull latest images
	@docker compose pull

up: start ## Alias for start
down: stop ## Alias for stop

# Service-specific logs
logs-proxy: ## Show HAProxy logs
	@docker compose logs -f openai-proxy

logs-whisper: ## Show Whisper logs
	@docker compose logs -f whisper

logs-ollama: ## Show Ollama logs
	@docker compose logs -f ollama

logs-tts: ## Show TTS logs
	@docker compose logs -f tts

# GPU monitoring
gpu: ## Show GPU usage with nvidia-smi
	@watch -n 1 nvidia-smi
