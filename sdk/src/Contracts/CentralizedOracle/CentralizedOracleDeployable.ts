import type { CentralizedOracleDeployOptions } from '../../types';

import abi from '../../abi/centralizedOracle';
import erc1976ProxyAbi from '../../abi/erc1967Proxy';

import bytecode from '../../bytecode/centralizedOracle';
import erc1976ProxyBytecode from '../../bytecode/erc1967Proxy';

import BaseConnection from '../../Connection/BaseConnection';

import Deployable from '../Deployable';

abstract class CentralizedOracleDeployable extends Deployable<typeof abi> {
  constructor(connection: BaseConnection, address: string) {
    super(abi, connection, address);
  }

  static getRawContract(connection: BaseConnection) {
    return this._getRawContract(abi, connection);
  }

  protected static async _deployProxy(
    connection: BaseConnection,
    options: CentralizedOracleDeployOptions,
    from?: string,
  ): Promise<string> {
    const implementationAddress = await this.deployImplementation(connection, from);

    const web3 = connection.getWeb3();
    const initializeCall = web3.eth.abi.encodeFunctionCall(abi[6], [options.owner]);

    return await this._deploy(
      'Centralized Oracle',
      erc1976ProxyAbi,
      connection,
      {
        data: erc1976ProxyBytecode,
        arguments: [implementationAddress, initializeCall],
      },
      from,
    );
  }

  public static async deployImplementation(
    connection: BaseConnection,
    from?: string,
  ): Promise<string> {
    return await this._deploy(
      'Centralized Oracle implementation',
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

export default CentralizedOracleDeployable;
