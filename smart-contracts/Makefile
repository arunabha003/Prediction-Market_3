-include .env

.PHONY: help all env clean install update build test coverage format deploy\:oracle deploy\:oracle\:sepolia deploy\:market-factory deploy\:market-factory\:sepolia setup\:local

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEFAULT_ANVIL_ADDRESS := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

DEPLOY_CENTRALIZED_ORACLE := forge script script/DeployCentralizedOracle.s.sol:DeployCentralizedOracle
DEPLOY_MARKET_FACTORY := forge script script/DeployMarketFactory.s.sol:DeployMarketFactory

CLEAN := forge clean
INSTALL_DEPS := rm -rf lib && forge install && forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.2.0 --no-commit && forge install OpenZeppelin/openzeppelin-foundry-upgrades@v0.3.7 --no-commit
UPDATE_DEPS := forge update
BUILD := forge build
TEST := forge test
COVERAGE := forge coverage
FORMAT := forge fmt

help:
	@echo "Usage:"
	@echo "  make help				Shows this help message"
	@echo "  make env				Creates the .env file"
	@echo "  make install				Installs the dependencies"
	@echo "  make update				Updates the dependencies"
	@echo "  make build				Builds the project"
	@echo "  make clean				Cleans the build output"
	@echo "  make test				Runs the tests"
	@echo "  make coverage				Runs the coverage"
	@echo "  make format				Formats the code"
	@echo "  make deploy:oracle			Deploys the Centralized Oracle contract"
	@echo "  make deploy:oracle:sepolia		Deploys the Centralized Oracle contract on Sepolia"
	@echo "  make deploy:market-factory		Deploys the Market Factory contract"
	@echo "  make deploy:market-factory:sepolia	Deploys the Market Factory contract on Sepolia"
	@echo "  make setup:local			Sets up the project locally"


all: env clean install update build test coverage format

env :; cp .env.example .env

clean  :; $(CLEAN)

install :; $(INSTALL_DEPS)

update:; $(UPDATE_DEPS)

build:; $(BUILD)

test :; $(TEST)

coverage :; $(COVERAGE)

format :; $(FORMAT)

LOCAL_NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
SEPOLIA_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(WALLET_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
OWNER := $(DEFAULT_ANVIL_ADDRESS)

# Deploy Centralized Oracle
deploy\:oracle:
	@echo "Deploying Centralized Oracle contract..."
	$(DEPLOY_CENTRALIZED_ORACLE) $(OWNER) --sig 'run(address)' $(LOCAL_NETWORK_ARGS)

deploy\:oracle\:sepolia:
	@echo "Deploying Centralized Oracle contract..."
	$(DEPLOY_CENTRALIZED_ORACLE) $(OWNER) --sig 'run(address)' $(SEPOLIA_ARGS)

# Deploy Market Factory
deploy\:market-factory:
	@echo "Deploying Market Factory contract..."
	$(DEPLOY_MARKET_FACTORY) $(OWNER) --sig 'run(address)' $(LOCAL_NETWORK_ARGS)

deploy\:market-factory\:sepolia:
	@echo "Deploying Market Factory contract..."
	$(DEPLOY_MARKET_FACTORY) $(OWNER) --sig 'run(address)' $(SEPOLIA_ARGS)

# Local Setup
setup\:local:
	@echo "Setting up project locally"
	$(CLEAN)
	$(CLEAR)
	$(INSTALL_DEPS)
	$(BUILD)
	@echo "Deploying Market Factory contract..."
	$(DEPLOY_MARKET_FACTORY) $(OWNER) --sig 'run(address)' $(LOCAL_NETWORK_ARGS)
	