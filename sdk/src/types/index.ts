export * from './Connection';
export * from './Contracts';

export type FormattedETH = {
  wei: string;
  gwei: string;
  eth: string;
  weiBigInt: bigint;
};

export type FormattedDate = {
  date: Date;
  timestamp: number;
  timestampMillis: number;
  formattedDate: string;
};
