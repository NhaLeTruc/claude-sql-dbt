.PHONY: setup test build docs shutdown

setup:
	@echo "🚀 Starting Docker services..."
	docker compose -f docker/docker-compose.yml up -d
	@echo "📦 Creating virtual environment..."
	python3 -m venv dbt_env
	@echo "⚙️  Installing dependencies..."
	./dbt_env/bin/pip install -r requirements.txt
	@echo "📚 Installing dbt packages..."
	./dbt_env/bin/dbt deps --project-dir dbt_project
	@echo "🌱 Loading seed data..."
	./dbt_env/bin/dbt seed --project-dir dbt_project
	@echo "✅ Setup complete!"

shutdown:
	@echo "🛑 Stopping Docker services..."
	docker compose -f docker/docker-compose.yml down --volumes --remove-orphans
	@echo "✅ Shutdown complete!"

test:
	@echo "🧪 Running dbt tests..."
	./dbt_env/bin/dbt run --project-dir dbt_project
	./dbt_env/bin/dbt test --project-dir dbt_project

build:
	@echo "🏗️  Building dbt project..."
	./dbt_env/bin/dbt build --project-dir dbt_project

docs:
	@echo "📖 Generating documentation..."
	./dbt_env/bin/dbt docs generate --project-dir dbt_project
	./dbt_env/bin/dbt docs serve --project-dir dbt_project