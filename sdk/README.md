# Prediction Market SDK

The SDK allows users to interact with the Prediction Market Protocol without worrying about the underlying details. It provides a set of tools and functions to easily create markets, add liquidity, trade shares, and claim rewards.

## Table of Contents

- [Prediction Market SDK](#prediction-market-sdk)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Setup](#setup)
  - [Usage](#usage)
  - [Testing](#testing)

## Overview

The Prediction Market SDK provides a way to interact with the Prediction Market Protocol. It abstracts the complexity of interacting with the smart contracts and provides a simple interface for developers.

## Setup

To set up the SDK locally, follow these steps:

1. **Clone the repository:**

   ```sh
   git clone https://github.com/asparuhdamyanov/svet-prediction-market-takehome
   cd sdk
   ```

2. **Install dependencies:**

   ```sh
   make install
   ```

3. **Build the SDK:**

   ```sh
   make build
   ```

## Usage

```javascript
const connection = new HttpConnection('http://localhost:8545');
// Or
const connection = new WebConnection();

const privateKey = process.env.WALLET_PRIVATE_KEY;
connection.addAccount(privateKey);

const marketFactoryAddress = '0x';
const marketFactory = MarketFactory.forAddress(marketFactoryAddress, connection);

marketFactory.setStartBlock(0);

const market = await marketFactory.getMarket(0);
const marketInfo = await market.getInfo();

const { sharesBought, amount, fee, executedPrice } = await market.buyShares({
  amount: 100n,
  outcomeIndex: 0,
  minOutcomeShares: 100n,
  deadline: Math.floor(Date.now() / 1000) + 60,
});
```

## Testing

To run the tests, use the following command:

1. **Unit tests:**

   ```sh
   make test:unit
   ```

2. **Integration tests:**

   Make sure `anvil` is running in another terminal

   ```sh
   cd ../smart-contracts
   anvil
   ```

   Run

   ```sh
   make test:integration
   ```
