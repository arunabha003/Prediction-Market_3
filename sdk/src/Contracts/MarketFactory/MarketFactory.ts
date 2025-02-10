import type { CreateMarketArgs, MarketFactoryDeployOptions } from '../../types';

import { EventLog } from 'web3';

import { getTimestamp } from '../../utils';

import BaseConnection from '../../Connection/BaseConnection';
import { handleCommonErrors } from '../../Contracts/ContractsErrors';

import { Market } from '../Market';

import MarketFactoryDeployable from './MarketFactoryDeployable';

class MarketFactory extends MarketFactoryDeployable {
  IMPLEMENTATION_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
  BPS = 10000;

  constructor(
    connection: BaseConnection,
    address: string,
    startBlock?: bigint,
    defaultSender?: string,
  ) {
    super(connection, address, startBlock, defaultSender);
  }

  public static forAddress(address: string, connection: BaseConnection): MarketFactory {
    return new MarketFactory(connection, address);
  }

  public static async deploy(
    connection: BaseConnection,
    options: MarketFactoryDeployOptions,
    from?: string,
  ): Promise<MarketFactory> {
    const blockNumber = await connection.getWeb3().eth.getBlockNumber();
    const address = await super._deployProxy(connection, options, from);
    const marketFactory = new MarketFactory(connection, address).setStartBlock(blockNumber);
    if (from) {
      marketFactory.setDefaultSender(from);
    }
    return marketFactory;
  }

  async createMarket(args: CreateMarketArgs, from?: string): Promise<Market> {
    this._validateCreateMarketArgs(args);
    args.closeTime = getTimestamp(args.closeTime).toString();
    args.feeBPS = args.feeBPS.toString();
    args.initialLiquidity = args.initialLiquidity.toString();
    args.resolveDelaySeconds = args.resolveDelaySeconds.toString();

    try {
      const tx = await this.contract.methods
        .createMarket(
          args.question,
          args.outcomeNames,
          args.closeTime,
          args.oracle || '0x0000000000000000000000000000000000000000',
          args.initialLiquidity,
          args.resolveDelaySeconds,
          args.feeBPS,
        )
        .send({ from: from || this.defaultSender, value: args.initialLiquidity.toString() });

      if (!tx.events) {
        throw new Error('Market not created');
      }
      const event = tx.events['MarketCreated'];
      const marketAddress = event.returnValues.marketAddress as string;

      return Market.forAddress(marketAddress, this.connection, event.blockNumber, from);
    } catch (error) {
      handleCommonErrors(error);

      throw error;
    }
  }

  async transferOwnership(newOwner: string, from?: string): Promise<void> {
    await this.contract.methods
      .transferOwnership(newOwner)
      .send({ from: from || this.defaultSender });
  }

  async setMarketImplementation(implementation: string, from?: string): Promise<void> {
    await this.contract.methods
      .setMarketImplementation(implementation)
      .send({ from: from || this.defaultSender });
  }

  async setMarketAMMImplementation(implementation: string, from?: string): Promise<void> {
    await this.contract.methods
      .setMarketAMMImplementation(implementation)
      .send({ from: from || this.defaultSender });
  }

  async setOracleImplementation(implementation: string, from?: string): Promise<void> {
    await this.contract.methods
      .setOracleImplementation(implementation)
      .send({ from: from || this.defaultSender });
  }

  async getMarketCount(): Promise<bigint> {
    return await this.contract.methods.getMarketCount().call<bigint>();
  }

  async getMarkets(): Promise<Market[]> {
    const count = await this.contract.methods.getMarketCount().call<bigint>();
    const markets: Market[] = [];
    for (let i = 0; i < count; i++) {
      markets.push(await this.getMarket(i));
    }
    return markets;
  }

  async getMarket(index: number): Promise<Market> {
    const address = await this.contract.methods.getMarket(index).call<string>();
    return Market.forAddress(address, this.connection, undefined, this.defaultSender);
  }

  async getOwner(): Promise<string> {
    return await this.contract.methods.owner().call<string>();
  }

  async getMarketImplementation(): Promise<string> {
    return await this.contract.methods.marketImplementation().call<string>();
  }

  async getMarketAMMImplementation(): Promise<string> {
    return await this.contract.methods.marketAMMImplementation().call<string>();
  }

  async getOracleImplementation(): Promise<string> {
    return await this.contract.methods.oracleImplementation().call<string>();
  }

  async getImplementation(): Promise<string> {
    const web3 = this.connection.getWeb3();
    const implementationAddressBytes = await web3.eth.getStorageAt(
      this.address,
      this.IMPLEMENTATION_SLOT,
    );
    const implementationAddress = web3.eth.abi.decodeParameter(
      'address',
      implementationAddressBytes,
    ) as string;
    return implementationAddress;
  }

  async getUserCreatedMarkets(user: string): Promise<Market[]> {
    const events = (await this.contract.getPastEvents('MarketCreated', {
      fromBlock: this.startBlock || undefined,
      filter: { creator: user },
    })) as EventLog[];

    return events.map(event =>
      Market.forAddress(
        event.returnValues.marketAddress as string,
        this.connection,
        event.blockNumber ? BigInt(event.blockNumber) : undefined,
      ),
    );
  }

  private _validateCreateMarketArgs(args: CreateMarketArgs) {
    if (args.question.length <= 6) {
      throw new Error('Question must be longer than 6 characters');
    }

    if (args.outcomeNames.length !== 2) {
      throw new Error('Only binary markets are supported');
    }

    if (args.closeTime instanceof Date) {
      args.closeTime = Math.floor(args.closeTime.getTime() / 1000);
    }

    if (Number(args.closeTime) <= Math.floor(Date.now() / 1000)) {
      throw new Error('Close time must be greater than current time');
    }

    if (BigInt(`${args.initialLiquidity}`) < 0n) {
      throw new Error('Initial liquidity must be greater than 0');
    }

    if (Number(args.resolveDelaySeconds) < 60 || Number(args.resolveDelaySeconds) > 604800) {
      throw new Error('Resolve delay must be greater than 1 minute and less than 7 days');
    }

    if (Number(args.feeBPS) < 0 || Number(args.feeBPS) > this.BPS) {
      throw new Error(`Fee BPS must be between 0 and ${this.BPS}`);
    }
  }
}

export default MarketFactory;
