-include .env

.PHONY: help clean install  build test

INSTALL_DEPS := rm -rf node_modules && pnpm i
BUILD_SDK := cd ./sdk && make build
LINK_SDK := pnpm link ./sdk

help:
	@echo "Usage:"
	@echo "  make help				Shows this help message"
	@echo "  make install				Installs the dependencies"
	@echo "  make setup				Installs the dependencies and links the sdk"

install :; $(INSTALL_DEPS)

setup:
	$(INSTALL_DEPS)
	$(BUILD_SDK)
	$(LINK_SDK)
	