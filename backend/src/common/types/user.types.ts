export interface Position {
  marketId: string;
  outcome: string;
  amount: string;
  entryPrice: string;
  currentPrice: string;
  pnl: string;
}

export interface UserMarket {
  id: string;
  title: string;
  chain: string;
  status: string;
  volume: string;
}
