# Prediction Market Smart Contracts

The platform allows users to create and participate in prediction markets, betting on outcomes with potential rewards based on accurate predictions or participate as a liquidity provider

## Table of Contents

- [Prediction Market Smart Contracts](#prediction-market-smart-contracts)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Architecture](#architecture)
  - [Setup](#setup)
  - [Deployment](#deployment)
  - [Contracts](#contracts)
    - [MarketFactory](#marketfactory)
    - [Market](#market)
    - [MarketAMM](#marketamm)
    - [Oracle](#oracle)
  - [Testing](#testing)
  - [Improvements](#improvements)

## Overview

The prediction market platform consists of several smart contracts that manage the creation and operation of prediction markets. Users can add liquidity, remove liquidity, buy shares, sell shares, and claim rewards based on the outcomes of the markets.

For a detailed overview click [here](./docs/overview.md)

## Architecture

The core contracts in this repository are:

- `MarketFactory`: A factory contract that creates and manages individual `Market` instances.
- `Market`: A contract that handles user betting logic, tracks outcomes, and manages reward distribution.
- `MarketAMM`: A contract used for calculations by the `Market` contract, implementing the constant product formula.
- `Oracle`: A contract that provides the outcome of the market.

## Setup

To set up the project locally, follow these steps:

1. **Clone the repository:**

   ```sh
   git clone https://github.com/asparuhdamyanov/svet-prediction-market-takehome
   cd smart-contracts
   ```

2. **Create `.env` file and fill the variables**

   ```sh
   make env
   ```

3. **Install dependencies and deploy local MarketFactory:**

   ```sh
   make setup:local
   ```

## Deployment

You can deploy the contracts locally, on sepolia or manually to any network:

1. **Deploy the Market Factory contract:**

   ```sh
   make deploy:market-factory
   ```

   or

   ```sh
   make deploy::market-factory:sepolia
   ```

   or

   ```sh
   forge script script/DeployMarketFactory.s.sol:DeployMarketFactory <owner> --sig 'run(address)' --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
   ```

2. **Deploy the Centralized Oracle contract:**

   ```sh
   make deploy:oracle
   ```

   or

   ```sh
   make deploy:oracle:sepolia
   ```

   or

   ```sh
   forge script script/DeployCentralizedOracle.s.sol:DeployCentralizedOracle <owner> --sig 'run(address)' --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
   ```

## Contracts

### MarketFactory

The `MarketFactory` contract is responsible for creating and managing individual `Market` instances. It stores a reference to the `Market` implementation contract and can create new `Market` instances using the `createMarket` function. The factory keeps track of all created markets for easy enumeration.

### Market

Each `Market` instance handles user betting logic, tracks outcomes, and manages reward distribution. The contract holds liquidity and integrates with an oracle to settle the market outcome. Users can add liquidity, buy shares, and claim rewards based on the resolved outcome.

### MarketAMM

The `MarketAMM` contract is used for calculations by the `Market` contract. It implements the constant product formula to manage the liquidity pool and calculate the prices of shares.

### Oracle

The `Oracle` contract provides the outcome of the market. In production, a real oracle might fetch data from trusted APIs (e.g., Chainlink). For demonstration purposes, the `CentralizedOracle` contract allows manual setting of the outcome.

## Testing

To run the tests, use the following command:

```sh
make test
```

```sh
make coverage
```

## Improvements

For a detailed description click [here](./docs/improvements.md)
