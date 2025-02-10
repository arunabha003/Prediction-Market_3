import Web3 from 'web3';

import BaseConnection from './BaseConnection';

class WebConnection extends BaseConnection {
  constructor() {
    if (!window.ethereum) {
      throw new Error('Wallet provider not found');
    }

    super(new Web3(window.ethereum));
  }

  listenToAccountChanges(handler: (accounts: string[]) => void) {
    window.ethereum.on('accountsChanged', handler);
  }

  removeAccountChangeListener(handler: (accounts: string[]) => void) {
    window.ethereum.removeListener('accountsChanged', handler);
  }
}

export default WebConnection;
