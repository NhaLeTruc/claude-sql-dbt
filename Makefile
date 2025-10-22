.PHONY: setup test build docs

setup:
	docker compose -f docker/docker-compose.yml up -d
	python3 -m venv dbt_venv && source dbt_env/bin/activate && pip install -r requirements.txt
	dbt deps --project-dir dbt_project
	dbt seed --project-dir dbt_project

shutdown:
	docker compose -f docker/docker-compose.yml down --volumes --remove-orphans

test:
	dbt test --no-partial-parse --project-dir dbt_project

build:
	dbt build --no-partial-parse --project-dir dbt_project

docs:
	dbt docs generate --project-dir dbt_project
	dbt docs serve --project-dir dbt_project