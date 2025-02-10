import type { CentralizedOracleDeployOptions } from '../../types';

import BaseConnection from '../../Connection/BaseConnection';

import CentralizedOracleDeployable from './CentralizedOracleDeployable';

class CentralizedOracle extends CentralizedOracleDeployable {
  constructor(connection: BaseConnection, address: string) {
    super(connection, address);
  }

  public static async deploy(
    connection: BaseConnection,
    options: CentralizedOracleDeployOptions,
    from?: string,
  ): Promise<CentralizedOracle> {
    const blockNumber = await connection.getWeb3().eth.getBlockNumber();
    const address = await super._deployProxy(connection, options, from);
    const oracle = new CentralizedOracle(connection, address).setStartBlock(blockNumber);
    if (from) {
      oracle.setDefaultSender(from);
    }
    return oracle;
  }
}

export default CentralizedOracle;
