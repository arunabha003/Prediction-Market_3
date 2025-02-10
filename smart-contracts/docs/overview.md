# Prediction Market Protocol Documentation

## Overview

The Prediction Market Protocol is a decentralized platform that allows users to create and participate in prediction markets. Users can bet on outcomes with potential rewards based on accurate predictions or participate as liquidity providers. The protocol leverages smart contracts to manage market creation, liquidity, and reward distribution.

## Architecture

The Prediction Market Protocol consists of the following main contracts:

1. **MarketFactory**: Manages the creation of individual `Market` instances.
2. **Market**: Handles user betting logic, tracks outcomes, and manages reward distribution.
3. **MarketAMM**: Implements the constant product formula for calculations.
4. **Oracle**: Provides the outcome of the market.

## Market Creation

To create a market, follow these steps:

1. Call the `createMarket` function of the `MarketFactory` contract, specifying the market details:
   - **question**: the name
   - **outcome names (only two)**: the outcome names
   - **close time**: the timestamp at which the market closes the trading
   - **oracle address**: the oracle that will contain the outcome
   - **initial liquidity**: initial liquidity provided by the creator
   - **resolve delay**: the time after the close time, after which the market can be resolved
   - **fee BPS**: the fee percentage between 0 and 10000
2. The `MarketFactory` contract deploys a new `Market` contract instance and initializes it with the provided details.

## Adding Liquidity

To add liquidity to a market, follow these steps:

1. Call the `addLiquidity` function of the `Market` contract, specifying the:
   - **amount**: amount of liquidity in ETH to add
   - **deadline**: the time of transaction expiration
2. The `Market` contract updates the liquidity pool and adjusts the user's liquidity shares accordingly. It will return only liquidity shares if the market is balanced, otherwise it will return both liquidity shares and shares from the most likely outcome

## Trading Shares

To trade shares in a market, follow these steps:

### Buying Shares

1. Call the `buy` function of the `Market` contract, specifying the:
   - **amount**: amount of ETH to exchange for shares before fees
   - **outcome index**: the index of the desired outcome
   - **minimum shares**: the minimum shares you will accept
   - **deadline**: the time of transaction expiration
2. The `Market` contract calculates the number of shares to be bought using the constant product formula and updates the user's share balance.

### Selling Shares

1. Call the `sell` function of the `Market` contract, specifying the:
   - **amount**: amount of ETH you want to receive before fees
   - **outcome index**: the index of the desired outcome
   - **maxium shares**: the maxium shares you want to give
   - **deadline**: the time of transaction expiration
2. The `Market` contract calculates the amount to be received using the constant product formula and updates the user's share balance.

## Removing Liquidity

To remove liquidity from a market, follow these steps:

1. Call the `removeLiquidity` function of the `Market` contract, specifying the:
   - **amount**: amount of liquidity shares to remove
   - **deadline**: the time of transaction expiration
2. The `Market` contract updates the liquidity pool and transfers the corresponding amount of funds back to the user. It will return only liquidity shares if the market is balanced, otherwise it will return both liquidity shares and shares from the less likely outcome
3. If the market is resolved, the liquidity provider will get a share of the winning outcome shares that are inside the pool based on their liquidity shares

## Resolving Market

To resolve a market, follow these steps:

1. Everyone can call `closeMarket` to close the trading
2. Wait for the resolve delay to pass
3. Everyone can call `resolveMarket` function of the `Market` contract to get the outcome from the oracle
4. The `Market` contract updates the market state to resolved and allows users to claim their rewards based on the outcome.

## Claiming Rewards

To claim rewards, follow these steps:

1. Call the `claimRewards` function of the `Market` contract after the market is resolved.
2. The `Market` contract transfers the rewards to the user based on their share holdings in the winning outcome.

## Claiming Fees

To claim the fees from liquidity providing, follow these steps:

1. Call the `claimFees` function of the `Market` contract.
2. The `Market` contract transfers the claimable fee rewards to the user.

## Actors and Their Roles

1. **Market Creator**:

   - Creates new markets using the `MarketFactory` contract.

2. **Liquidity Provider**:

   - Adds liquidity to markets by depositing funds.
   - Receives liquidity shares representing their stake in the market.
   - Can claim liquidity after resolved and claim a proportional share of the market's funds.

3. **Trader**:

   - Buys and sells shares in market outcomes.
   - Bets on the outcomes of markets to potentially earn rewards.

4. **Oracle**:

   - Provides the outcome of the market.

5. **User**:
   - Participates in markets by buying shares, adding liquidity, and claiming rewards.
   - Interacts with the protocol through the provided smart contract functions.

## Upgradeability

The `MarketFactory` contract use the UUPS upgradeability pattern and can be upgraded by the owner.
