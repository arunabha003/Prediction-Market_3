import abi from '../../abi/market';

import bytecode from '../../bytecode/market';

import BaseConnection from '../../Connection/BaseConnection';

import Deployable from '../Deployable';

abstract class MarketDeployable extends Deployable<typeof abi> {
  constructor(
    connection: BaseConnection,
    address: string,
    startBlock?: bigint | number,
    defaultSender?: string,
  ) {
    super(abi, connection, address, startBlock, defaultSender);
  }

  static getRawContract(connection: BaseConnection) {
    return this._getRawContract(abi, connection);
  }

  public static async deployImplementation(
    connection: BaseConnection,
    from?: string,
  ): Promise<string> {
    return await this._deploy(
      'Market implementation',
      abi,
      connection,
      { data: bytecode, arguments: [] },
      from,
    );
  }
}

export default MarketDeployable;
