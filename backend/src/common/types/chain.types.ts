export enum Chain {
  Ethereum = 'ethereum',
  Polygon = 'polygon',
  Sepolia = 'sepolia',
  Local = 'Local',
}

export type ChainConfigValue = { rpcUrl: string; chainId: number };

export type ChainConfig = Record<Chain, ChainConfigValue>;

export interface IChainContext {
  chainId: number;
  chainName: Chain;
  rpcUrl: string;
}
