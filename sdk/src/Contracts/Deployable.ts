import { ContractAbi, ContractConstructorArgs, HexString } from 'web3';

import BaseConnection from '../Connection/BaseConnection';

import BaseContract from './BaseContract';

abstract class Deployable<Abi extends ContractAbi> extends BaseContract<Abi> {
  constructor(
    abi: Abi,
    connection: BaseConnection,
    address: string,
    startBlock?: bigint | number,
    defaultSender?: string,
  ) {
    super(abi, connection, address, startBlock, defaultSender);
  }

  protected static async _deploy<Abi extends ContractAbi>(
    name: string,
    abi: Abi,
    connection: BaseConnection,
    options: {
      data?: HexString;
      input?: HexString;
      arguments?: ContractConstructorArgs<Abi>;
    },
    from?: string,
  ): Promise<string> {
    if (from === undefined) {
      const web3 = connection.getWeb3();
      const accounts = await web3.eth.getAccounts();
      if (accounts.length === 0) {
        throw new Error('No accounts available');
      }
      from = accounts[0];
    }

    const contract = this._getRawContract(abi, connection);
    const tx = await contract.deploy(options).send({ from });

    if (tx.options.address === undefined) {
      throw new Error(`Failed to deploy ${name}`);
    }

    return tx.options.address;
  }
}

export default Deployable;
