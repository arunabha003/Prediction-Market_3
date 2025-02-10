-include .env

.PHONY: help clean install  build test

CLEAN := pnpm clean
INSTALL_DEPS := rm -rf node_modules && pnpm i
BUILD := $(CLEAN) && pnpm build
TEST_UNIT := pnpm test:unit
TEST_INTEGRATION := pnpm test:integration

help:
	@echo "Usage:"
	@echo "  make help				Shows this help message"
	@echo "  make install				Installs the dependencies"
	@echo "  make build				Builds the project"
	@echo "  make clean				Cleans the build output"
	@echo "  make test:unit			Runs the unit tests"
	@echo "  make test:integration			Runs the integration tests"

install :; $(INSTALL_DEPS)

build:; $(BUILD)

clean  :; $(CLEAN)

test\:unit :; $(TEST_UNIT)

test\:integration :; $(TEST_INTEGRATION)	