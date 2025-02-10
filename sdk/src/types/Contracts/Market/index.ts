import { FormattedETH } from '../../../types';

export type MarketAddLiquidityArgs = {
  amount: bigint | number | string;
  deadline: Date | bigint | number | string;
};

export type MarketAddLiquidityResult = {
  liquidityShares: bigint;
  outcomeShares: bigint[];
};

export type MarketRemoveLiquidityArgs = {
  shares: bigint | number | string;
  deadline: Date | bigint | number | string;
};

export type MarketRemoveLiquidityResult = {
  amount: FormattedETH;
  outcomeShares: bigint[];
};

export type MarketBuySharesArgs = {
  amount: bigint | number | string;
  outcomeIndex: bigint | number | string;
  minOutcomeShares: bigint | number | string;
  deadline: Date | bigint | number | string;
};

export type MarketBuySharesResult = {
  amount: FormattedETH;
  sharesBought: bigint;
  fee: FormattedETH;
  executedPrice: number;
};

export type MarketSellSharesArgs = {
  receivedAmount: bigint | number | string;
  outcomeIndex: bigint | number | string;
  maxOutcomeShares: bigint | number | string;
  deadline: Date | bigint | number | string;
};

export type MarketSellSharesResult = {
  receivedAmount: FormattedETH;
  sharesSold: bigint;
  fee: FormattedETH;
  executedPrice: number;
};

export type ClaimResult = {
  amount: FormattedETH;
};

export enum MarketState {
  Open,
  Closed,
  Resolved,
}

export type MarketInfo = {
  address: string;
  question: string;
  outcomeCount: number;
  closeTime: Date;
  createTime: Date;
  closedAt: Date | null;
};

export type MarketInfoFull = MarketInfo & {
  outcomeNames: string[];
  outcomePrices: number[];
  feeBPS: number;
  state: MarketState;
  resolveDelay: number;
  resolved: boolean;
  resolvedOutcomeIndex: number | null;
  creator: string;
  oracle: string;
  marketAMM: string;
};

export type Shares = {
  total: bigint;
  available: bigint;
};

export type Outcome = {
  name: string;
  shares: Shares;
};

export type MarketPoolData = {
  balance: bigint;
  liquidity: bigint;
  totalAvailableShares: bigint;
  outcomes: Outcome[];
};

export type MarketResolutionData = {
  resolved: boolean;
  resolvedOutcomeIndex: bigint | null;
  resolveDelay: bigint;
};

export type MarketUserFeeState = {
  claimable: bigint;
  claimed: bigint;
};

export type MarketUserPosition = {
  outcomeIndex: number;
  shares: bigint;
  avgEntryPrice: number;
  pnl: bigint;
  pnlPercentage: number;
  currentSharesValue: bigint;
  currentPrice: number;
};
