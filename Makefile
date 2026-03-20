SHELL := /bin/bash

VERSION ?= v1.0.0

.PHONY: help syntax lint test ci install uninstall build clean release

help:
	@echo "Available commands:"
	@echo "  make syntax      Check bash syntax"
	@echo "  make lint        Run ShellCheck"
	@echo "  make test        Run BATS tests"
	@echo "  make ci          Run all checks"
	@echo "  make install     Install ssha"
	@echo "  make uninstall   Remove ssha"
	@echo "  make build       Build release zip"
	@echo "  make clean       Clean dist/"
	@echo "  make release     Tag + push release"

# --- EXISTANT (inchangé) ---

syntax:
	bash -n bin/ssha
	find lib -name "*.sh" -exec bash -n {} \;

lint:
	shellcheck -x bin/ssha
	shellcheck lib/*.sh

test:
	bats tests

ci: syntax lint test

# --- NOUVEAU ---

install:
	./install.sh

uninstall:
	./uninstall.sh

build:
	./scripts/build.sh $(VERSION)

clean:
	rm -rf dist

release: clean build
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)