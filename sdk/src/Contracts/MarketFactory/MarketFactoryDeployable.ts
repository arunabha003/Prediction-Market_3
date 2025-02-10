import type { MarketFactoryDeployOptions } from '../../types';

import abi from '../../abi/marketFactory';
import erc1976ProxyAbi from '../../abi/erc1967Proxy';

import bytecode from '../../bytecode/marketFactory';
import erc1976ProxyBytecode from '../../bytecode/erc1967Proxy';

import BaseConnection from '../../Connection/BaseConnection';

import Deployable from '../Deployable';

class MarketFactoryDeployable extends Deployable<typeof abi> {
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

  protected static async _deployProxy(
    connection: BaseConnection,
    options: MarketFactoryDeployOptions,
    from?: string,
  ): Promise<string> {
    const implementationAddress = await this._deployImplementation(connection, from);

    const web3 = connection.getWeb3();
    const initializeCall = web3.eth.abi.encodeFunctionCall(abi[6], [
      options.owner,
      options.marketImplementation,
      options.marketAMMImplementation,
      options.defaultOracleImplementation,
    ]);

    return await this._deploy(
      'Market Factory',
      erc1976ProxyAbi,
      connection,
      {
        data: erc1976ProxyBytecode,
        arguments: [implementationAddress, initializeCall],
      },
      from,
    );
  }

  protected static async _deployImplementation(
    connection: BaseConnection,
    from?: string,
  ): Promise<string> {
    return await this._deploy(
      'MarketFactory implementation',
      abi,
      connection,
      {
        data: bytecode,
        arguments: [],
      },
      from,
    );
  }
}

export default MarketFactoryDeployable;
