// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

error OnlyThreeOutcomeMarketSupported();
/// @notice This error is thrown when the market is initialized with more than two outcomes
error OnlyBinaryMarketSupported();

/// @notice This error is thrown when the market is initialized with an invalid close time
error InvalidCloseTime();

/// @notice This error is thrown when the resolve delay is invalid
error InvalidResolveDelay(uint256 MIN_RESOLVE_DELAY, uint256 MAX_RESOLVE_DELAY);

/// @notice This error is thrown when the market is not in the correct state and a user tries to perform an action
error InvalidMarketState();

/// @notice This error is thrown when the close time of the market has passed
error MarketClosed();

/// @notice This error is thrown when the buy shares don't meet the minimum shares required by the user
error MinimumSharesNotMet();

/// @notice This error is thrown when the required shares to sell in order to receive the amount of ETH are not met
error MaxSharesNotMet();

/// @notice This error is thrown when the user has insufficient shares to execute the action
error InsufficientShares();

/// @notice This error is thrown when the pool has insufficient liquidity to execute the action
error InsufficientLiquidity();

/// @notice This error is thrown when the market close time has not passed
error MarketCloseTimeNotPassed();

/// @notice This error is thrown when the market has to wait for a delay after closing
error MarketResolveDelayNotPassed();

/// @notice This error is thrown when the user has no rewards to claim
error NoRewardsToClaim();

/// @notice This error is thrown when the user has no liquidity to claim
error NoLiquidityToClaim();

/// @notice This error is thrown when the oracle has not resolved the market
error OracleNotResolved();

/// @notice This error is thrown when the feeBPS is invalid
error InvalidFeeBPS();
