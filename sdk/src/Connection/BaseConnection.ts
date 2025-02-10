import type { BaseConnectionProps } from '../types/Connection';

import Web3 from 'web3';

abstract class BaseConnection {
  protected web3: Web3;

  constructor(props: BaseConnectionProps) {
    if (props instanceof Web3) {
      this.web3 = props;
    } else {
      this.web3 = new Web3(props.rpcUrl);
    }
  }

  getWeb3(): Web3 {
    return this.web3;
  }

  getAccounts(): Promise<string[]> {
    return this.web3.eth.getAccounts();
  }

  setDefaultAccount(account: string): void {
    this.web3.eth.defaultAccount = account;
  }

  getDefaultAccount(): string | undefined {
    return this.web3.eth.defaultAccount;
  }
}

export default BaseConnection;
