import abi from '../../abi/marketAMM';

import bytecode from '../../bytecode/marketAMM';

import BaseConnection from '../../Connection/BaseConnection';

import Deployable from '../Deployable';

abstract class MarketAMMDeployable extends Deployable<typeof abi> {
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
      'MarketAMM implementation',
      abi,
      connection,
      { data: bytecode, arguments: [] },
      from,
    );
  }
}

export default MarketAMMDeployable;
