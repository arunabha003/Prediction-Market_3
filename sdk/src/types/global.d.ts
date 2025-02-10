import { MetaMaskProvider, Web3APISpec } from 'web3';

declare global {
  interface Window {
    ethereum: MetaMaskProvider<Web3APISpec>;
  }
}

export {};
