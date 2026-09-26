.PHONY: check install run stack-start stack-stop stack-status

VENV := .venv
PY := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

install:
	python3 -m venv $(VENV)
	$(PIP) install -q -U pip
	$(PIP) install -q -r requirements.txt

check: install
	$(PY) -m pytest tests/ -m "not slow"

run: install
	$(PY) -m uvicorn service.main:create_app --factory --host 127.0.0.1 --port 8288

stack-start:
	bash scripts/l2-stack.sh start

stack-stop:
	bash scripts/l2-stack.sh stop

stack-status:
	bash scripts/l2-stack.sh status
