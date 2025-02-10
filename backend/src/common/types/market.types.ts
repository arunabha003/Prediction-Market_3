import { Chain } from './chain.types';

export interface Market {
  id: string;
  title: string;
  chain: Chain;
  outcomes: string[];
  endDate: Date;
  liquidity: string;
}

export interface MarketCreationResponse {
  success: boolean;
  marketId: string;
  chain: Chain;
  details: MarketDetails;
}

export interface MarketDetails {
  title: string;
  outcomes: string[];
  endDate: Date;
  liquidity: string;
}
