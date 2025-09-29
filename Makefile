SHELL := /usr/bin/env bash
ROOT  := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT   := $(ROOT)/out
DIST  := $(ROOT)/dist
SRC   := $(ROOT)/src
RELEASE ?= dev

.PHONY: help tools build test run pack clean

help: ## Muestra ayuda de targets
	@awk '/^[a-zA-Z0-9_\-]+:.*##/ {gsub(":.*##",": "); printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

tools: ## Verifica utilidades del temario
	@for c in ip ss curl nc ssh scp rsync journalctl bats; do \
		command -v $$c >/dev/null 2>&1 || { echo "Falta $$c"; exit 1; }; \
	done; echo "OK herramientas"

build: $(OUT)/.deps.ok ## Prepara artefactos intermedios cacheables
$(OUT)/.deps.ok: $(SRC)/smoke.sh Makefile
	@mkdir -p "$(OUT)/raw"
	@date -u +"%FT%TZ" > "$(OUT)/.deps.ok"
	@echo "deps ok"

test: ## Ejecuta pruebas Bats (AAA/RGR)
	@bats -T "$(ROOT)/tests"

run: ## Orquesta sondas y genera out/report.csv
	@"$(SRC)/smoke.sh"

pack: ## Empaqueta reproducible en dist/ (usa RELEASE)
	@mkdir -p "$(DIST)"
	@tar -czf "$(DIST)/pc2-smoke-$(RELEASE).tar.gz" -C "$(ROOT)" src docs systemd Makefile
	@echo "Paquete: $(DIST)/pc2-smoke-$(RELEASE).tar.gz"

clean: ## Limpieza segura
	@rm -rf "$(OUT)"/* "$(DIST)"/* 2>/dev/null || true
	@mkdir -p "$(OUT)" "$(DIST)"
	@echo "Limpio"