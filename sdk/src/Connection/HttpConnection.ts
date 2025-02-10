import Web3 from 'web3';

import BaseConnection from './BaseConnection';

class HttpConnection extends BaseConnection {
  constructor(rpcUrl: string) {
    super(new Web3(new Web3.providers.HttpProvider(rpcUrl)));
  }

  static forNetwork(rpcUrl: string): HttpConnection {
    return new HttpConnection(rpcUrl);
  }

  addAccount(privateKey: string): void {
    this.web3.eth.accounts.wallet.add(privateKey);
  }
}

export default HttpConnection;
