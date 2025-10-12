.PHONY: help start stop restart logs status backup restore clean update

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

start: ## Start the Maven repository
	@echo "🚀 Starting DPC Maven Repository..."
	@docker-compose up -d
	@echo "✅ Repository started. Access at http://localhost:8081"

stop: ## Stop the Maven repository
	@echo "🛑 Stopping DPC Maven Repository..."
	@docker-compose down
	@echo "✅ Repository stopped."

restart: ## Restart the Maven repository
	@echo "🔄 Restarting DPC Maven Repository..."
	@docker-compose restart
	@echo "✅ Repository restarted."

logs: ## View logs (use Ctrl+C to exit)
	@docker-compose logs -f

status: ## Show status of the Maven repository
	@docker-compose ps
	@echo ""
	@echo "Docker volumes:"
	@docker volume ls | grep nexus-data || echo "No nexus-data volume found"

backup: ## Create a backup of the repository data
	@./backup.sh

restore: ## Restore from backup (Usage: make restore BACKUP=path/to/backup.tar.gz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "❌ Error: Please specify BACKUP=path/to/backup.tar.gz"; \
		exit 1; \
	fi
	@./restore.sh $(BACKUP)

clean: ## Remove all containers and volumes (WARNING: destroys all data!)
	@echo "⚠️  WARNING: This will remove all containers and data!"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker-compose down -v; \
		echo "✅ Cleanup complete."; \
	else \
		echo "Cancelled."; \
	fi

update: ## Update to the latest version
	@echo "📥 Pulling latest image..."
	@docker-compose pull
	@echo "🔄 Recreating container..."
	@docker-compose up -d
	@echo "✅ Update complete."

setup: ## Run initial setup
	@./setup.sh

password: ## Retrieve the initial admin password
	@echo "🔑 Initial admin password:"
	@docker exec dpc-maven-repo cat /nexus-data/admin.password 2>/dev/null || echo "Password file not found. Repository may still be initializing."

shell: ## Open a shell in the Nexus container
	@docker exec -it dpc-maven-repo /bin/bash
