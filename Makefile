.PHONY: up down status logs smoke test lint clean

up:
	./scripts/ops.sh up

down:
	./scripts/ops.sh down

status:
	./scripts/ops.sh status

logs:
	./scripts/ops.sh logs

smoke:
	./scripts/ops.sh smoke

# Start the stack and run the smoke tests.
test: up smoke

# Optional: needs hadolint and shellcheck installed.
lint:
	hadolint Dockerfile
	shellcheck scripts/ops.sh

# Stop the stack AND delete the database volume.
clean:
	docker compose down -v --remove-orphans
