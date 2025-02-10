import { Contract, ContractAbi } from 'web3';

import BaseConnection from '../Connection/BaseConnection';

abstract class BaseContract<Abi extends ContractAbi> {
  address: string;

  protected contract: Contract<Abi>;
  protected connection: BaseConnection;
  protected defaultSender: string;
  protected startBlock: bigint | null = null;

  constructor(
    abi: Abi,
    connection: BaseConnection,
    address: string,
    startBlock?: bigint | number,
    defaultSender?: string,
  ) {
    const web3 = connection.getWeb3();

    this.address = address;
    this.connection = connection;
    this.contract = new web3.eth.Contract(abi, address);
    this.contract.handleRevert = true;

    this.defaultSender = defaultSender || web3.defaultAccount || '';

    if (startBlock) {
      this.setStartBlock(startBlock);
    }
  }

  public getContract(): Contract<Abi> {
    return this.contract;
  }

  public setStartBlock(startBlock: bigint | number) {
    if (typeof startBlock === 'number') {
      startBlock = BigInt(`${startBlock}`);
    }
    this.startBlock = startBlock;
    return this;
  }

  public getStartBlock(): bigint | null {
    return this.startBlock;
  }

  public setDefaultSender(sender: string) {
    this.defaultSender = sender;
    return this;
  }

  public getDefaultSender(): string {
    return this.defaultSender;
  }

  protected static _getRawContract<Abi extends ContractAbi>(
    abi: Abi,
    connection: BaseConnection,
  ): Contract<Abi> {
    const web3 = connection.getWeb3();
    return new web3.eth.Contract(abi);
  }
}

export default BaseContract;
