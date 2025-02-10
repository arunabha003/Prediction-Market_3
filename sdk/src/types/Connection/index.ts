import Web3 from 'web3';

export type BaseConnectionProps =
  | Web3
  | {
      rpcUrl: string;
    };
