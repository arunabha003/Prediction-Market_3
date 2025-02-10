export const AmountMismatchError = (args: { [K in string]: unknown }) => {
  return `Amount ${args[1]} does not match expected amount ${args[0]}`;
};

export const DeadlinePassedError = () => {
  return `Transaction deadline has passed`;
};

export const InsufficientSharesError = () => {
  return `Insufficient shares`;
};

export const InvalidCloseTimeError = () => {
  return `Invalid close time`;
};

export const InvalidFeeBPSError = () => {
  return `Invalid fee BPS`;
};

export const InvalidInitializationError = () => {
  return `Invalid initialization`;
};

export const InvalidMarketStateError = () => {
  return `Invalid market state`;
};

export const InvalidResolveDelayError = (args: { [K in string]: unknown }) => {
  return `Invalid resolve delay. Must be between ${args[0]} and ${args[1]}`;
};

export const MarketCloseTimeNotPassedError = () => {
  return `Market close time has not passed`;
};

export const MarketClosedError = () => {
  return `Market is closed`;
};

export const MarketResolveDelayNotPassedError = () => {
  return `Market resolve delay has not passed`;
};

export const MaxSharesNotMetError = () => {
  return `Maximum shares not met`;
};

export const MinimumSharesNotMetError = () => {
  return `Minimum shares not met`;
};

export const NoLiquidityToClaimError = () => {
  return `No liquidity to claim`;
};

export const NoRewardsToClaimError = () => {
  return `No rewards to claim`;
};

export const NotInitializingError = () => {
  return `Not initializing`;
};

export const OnlyBinaryMarketSupportedError = () => {
  return `Only binary market supported`;
};

export const OracleNotResolvedError = () => {
  return `Oracle not resolved`;
};

export const TransferFailedError = () => {
  return `Transfer failed`;
};

export const ZeroAddressError = () => {
  return `Zero address`;
};

const errors: { [CustomError: string]: (args: { [K in string]: unknown }) => string } = {
  AmountMismatch: AmountMismatchError,
  DeadlinePassed: DeadlinePassedError,
  InsufficientShares: InsufficientSharesError,
  InvalidCloseTime: InvalidCloseTimeError,
  InvalidFeeBPS: InvalidFeeBPSError,
  InvalidInitialization: InvalidInitializationError,
  InvalidMarketState: InvalidMarketStateError,
  InvalidResolveDelay: InvalidResolveDelayError,
  MarketCloseTimeNotPassed: MarketCloseTimeNotPassedError,
  MarketClosed: MarketClosedError,
  MarketResolveDelayNotPassed: MarketResolveDelayNotPassedError,
  MaxSharesNotMet: MaxSharesNotMetError,
  MinimumSharesNotMet: MinimumSharesNotMetError,
  NoLiquidityToClaim: NoLiquidityToClaimError,
  NoRewardsToClaim: NoRewardsToClaimError,
  NotInitializing: NotInitializingError,
  OnlyBinaryMarketSupported: OnlyBinaryMarketSupportedError,
  OracleNotResolved: OracleNotResolvedError,
  TransferFailed: TransferFailedError,
  ZeroAddress: ZeroAddressError,
};

export default errors;
