import Web3 from 'web3';

import BaseConnection from './BaseConnection';

class AnvilConnection extends BaseConnection {
  constructor() {
    super(new Web3('http://localhost:8545'));
  }

  addAccount(privateKey: string): void {
    this.web3.eth.accounts.wallet.add(privateKey);
  }
}

export default AnvilConnection;
