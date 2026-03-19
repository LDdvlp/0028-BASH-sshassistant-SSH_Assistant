SHELL := /bin/bash

.PHONY: syntax lint test ci

syntax:
	bash -n bin/ssha
	find lib -name "*.sh" -exec bash -n {} \;

lint:
	shellcheck -x bin/ssha
	shellcheck lib/*.sh

test:
	bats tests

ci: syntax lint test