import BaseConnection from '../../Connection/BaseConnection';

import MarketAMMDeployable from './MarketAMMDeployable';

class MarketAMM extends MarketAMMDeployable {
  constructor(connection: BaseConnection, address: string) {
    super(connection, address);
  }

  public static forAddress(address: string, connection: BaseConnection): MarketAMM {
    return new MarketAMM(connection, address);
  }

  async getBuyShares(
    amount: bigint | number,
    outcomeIndex: bigint | number,
    liquidity: bigint | number,
    outcomeShares: bigint[] | number[],
  ) {
    return await this.contract.methods
      .getBuyOutcomeData(amount, outcomeIndex, {
        liquidity,
        outcomeShares,
      })
      .call();
  }

  async getSellShares(
    amount: bigint | number,
    outcomeIndex: bigint | number,
    liquidity: bigint | number,
    outcomeShares: bigint[] | number[],
  ) {
    return await this.contract.methods
      .getSellOutcomeData(amount, outcomeIndex, {
        liquidity,
        outcomeShares,
      })
      .call();
  }
}

export default MarketAMM;
