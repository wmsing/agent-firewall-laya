.PHONY: check install run

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
