export type MarketFactoryDeployOptions = {
  owner: string;
  marketImplementation: string;
  marketAMMImplementation: string;
  defaultOracleImplementation: string;
};

export type CreateMarketArgs = {
  question: string;
  outcomeNames: string[];
  closeTime: Date | number | string;
  oracle?: string;
  initialLiquidity: number | bigint | string;
  resolveDelaySeconds: number | bigint | string;
  feeBPS: number | bigint | string;
};
