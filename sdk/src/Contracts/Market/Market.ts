import { type EventLog, type MatchPrimitiveType, type Uint256 } from 'web3';
import type {
  MarketBuySharesResult,
  MarketRemoveLiquidityResult,
  MarketSellSharesResult,
  MarketAddLiquidityArgs,
  MarketAddLiquidityResult,
  MarketBuySharesArgs,
  MarketInfo,
  MarketInfoFull,
  MarketRemoveLiquidityArgs,
  MarketSellSharesArgs,
  Outcome,
  ClaimResult,
  MarketPoolData,
  MarketResolutionData,
  MarketUserFeeState,
  MarketUserPosition,
} from '../../types/Contracts';

import BaseConnection from '../../Connection/BaseConnection';
import { handleCommonErrors } from '../../Contracts/ContractsErrors';

import { MarketState } from '../../types/Contracts/Market';

import { BPS, ONE, assertDeadline, getTimestamp, formatETH } from '../../utils';

import MarketDeployable from './MarketDeployable';
import { MarketAMM } from '../MarketAMM';

class Market extends MarketDeployable {
  constructor(
    connection: BaseConnection,
    address: string,
    startBlock?: bigint | number,
    defaultSender?: string,
  ) {
    super(connection, address, startBlock, defaultSender);
  }

  public static forAddress(
    address: string,
    connection: BaseConnection,
    startBlock?: bigint | number,
    defaultSender?: string,
  ): Market {
    return new Market(connection, address, startBlock, defaultSender);
  }

  public async addLiquidity(
    args: MarketAddLiquidityArgs,
    from?: string,
  ): Promise<MarketAddLiquidityResult> {
    assertDeadline(args.deadline);
    args.amount = args.amount.toString();
    args.deadline = getTimestamp(args.deadline).toString();

    const userOutcomeSharesBefore = await this.getUserOutcomeShares(from || this.defaultSender);

    try {
      const tx = await this.contract.methods
        .addLiquidity(args.amount, args.deadline)
        .send({ from: from || this.defaultSender, value: args.amount });

      if (!tx.events) {
        throw new Error('Liquidity Added event not found');
      }
      const event = tx.events['LiquidityAdded'];
      const liquidityShares = event.returnValues._liquidityShares as bigint;

      /* Get the user outcome shares after adding liquidity */
      const userOutcomeSharesAfter = await this.getUserOutcomeShares(from || this.defaultSender);
      const receivedShares = userOutcomeSharesAfter.map(
        (sharesAfter, i) => sharesAfter - userOutcomeSharesBefore[i],
      );

      return { liquidityShares, outcomeShares: receivedShares };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async removeLiquidity(
    args: MarketRemoveLiquidityArgs,
    from?: string,
  ): Promise<MarketRemoveLiquidityResult> {
    assertDeadline(args.deadline);
    args.shares = args.shares.toString();
    args.deadline = getTimestamp(args.deadline).toString();

    const userOutcomeSharesBefore = await this.getUserOutcomeShares(from || this.defaultSender);

    try {
      const tx = await this.contract.methods
        .removeLiquidity(args.shares, args.deadline)
        .send({ from: from || this.defaultSender });

      if (!tx.events) {
        throw new Error('Liquidity Removed event not found');
      }
      const event = tx.events['LiquidityRemoved'];
      const receivedAmount = event.returnValues._amount as bigint;

      const userOutcomeSharesAfter = await this.getUserOutcomeShares(from || this.defaultSender);
      const receivedShares = userOutcomeSharesAfter.map(
        (sharesAfter, i) => sharesAfter - userOutcomeSharesBefore[i],
      );

      return { amount: formatETH(receivedAmount), outcomeShares: receivedShares };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async buyShares(args: MarketBuySharesArgs, from?: string): Promise<MarketBuySharesResult> {
    assertDeadline(args.deadline);
    args.deadline = getTimestamp(args.deadline).toString();

    args.amount = args.amount.toString();
    args.deadline = getTimestamp(args.deadline).toString();

    args.minOutcomeShares = args.minOutcomeShares.toString();

    try {
      const tx = await this.contract.methods
        .buyShares(args.amount, args.outcomeIndex, args.minOutcomeShares, args.deadline)
        .send({ from: from || this.defaultSender, value: args.amount });

      if (!tx.events) {
        throw new Error('Buy Shares event not found');
      }

      const sharesBoughtEvent = tx.events['SharesBought'];
      const sharesBought = sharesBoughtEvent.returnValues._shares as bigint;
      const fee = sharesBoughtEvent.returnValues._fee as bigint;
      const amountAfterFee = BigInt(`${args.amount}`) - fee;
      const executedPrice = Number((amountAfterFee * ONE) / sharesBought) / Number(ONE);

      return {
        amount: formatETH(amountAfterFee),
        sharesBought,
        fee: formatETH(fee),
        executedPrice,
      };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async sellShares(
    args: MarketSellSharesArgs,
    from?: string,
  ): Promise<MarketSellSharesResult> {
    assertDeadline(args.deadline);
    args.receivedAmount = args.receivedAmount.toString();
    args.deadline = getTimestamp(args.deadline).toString();

    args.maxOutcomeShares = args.maxOutcomeShares.toString();
    args.outcomeIndex = args.outcomeIndex.toString();

    try {
      const tx = await this.contract.methods
        .sellShares(args.receivedAmount, args.outcomeIndex, args.maxOutcomeShares, args.deadline)
        .send({ from: from || this.defaultSender, value: args.receivedAmount });

      if (!tx.events) {
        throw new Error('Shares Sold event not found');
      }

      const event = tx.events['SharesSold'];
      const receivedAmount = event.returnValues._amount as bigint;
      const sharesSold = event.returnValues._shares as bigint;
      const fee = event.returnValues._fee as bigint;

      const executedPrice = Number((receivedAmount * ONE) / sharesSold) / Number(ONE);

      return {
        receivedAmount: formatETH(receivedAmount),
        sharesSold,
        fee: formatETH(fee),
        executedPrice,
      };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async closeMarket(from?: string): Promise<void> {
    try {
      await this.contract.methods.closeMarket().send({ from: from || this.defaultSender });
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async resolveMarket(from?: string): Promise<void> {
    try {
      await this.contract.methods.resolveMarket().send({ from: from || this.defaultSender });
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async claimFees(from?: string): Promise<ClaimResult> {
    try {
      const tx = await this.contract.methods.claimFees().send({ from: from || this.defaultSender });

      if (!tx.events) {
        throw new Error('Fees Claimed event not found');
      }

      const event = tx.events['FeesClaimed'];
      const amount = event.returnValues._amount as bigint;

      return { amount: formatETH(amount) };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async claimLiquidity(from?: string): Promise<ClaimResult> {
    try {
      const tx = await this.contract.methods
        .claimLiquidity()
        .send({ from: from || this.defaultSender });

      if (!tx.events) {
        throw new Error('Liquidity Claimed event not found');
      }

      const event = tx.events['LiquidityClaimed'];
      const amount = event.returnValues._amount as bigint;

      return { amount: formatETH(amount) };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async claimRewards(from?: string): Promise<ClaimResult> {
    try {
      const tx = await this.contract.methods
        .claimRewards()
        .send({ from: from || this.defaultSender });

      if (!tx.events) {
        throw new Error('Rewards Claimed event not found');
      }

      const event = tx.events['RewardsClaimed'];
      const amount = event.returnValues._amount as bigint;

      return { amount: formatETH(amount) };
    } catch (error) {
      handleCommonErrors(error);
      throw error;
    }
  }

  public async getInfo(): Promise<MarketInfo> {
    const info = await this.contract.methods.getInfo().call<{
      question: string;
      outcomeCount: MatchPrimitiveType<Uint256, bigint>;
      closeTime: MatchPrimitiveType<Uint256, bigint>;
      createTime: MatchPrimitiveType<Uint256, bigint>;
      closedAt: MatchPrimitiveType<Uint256, bigint>;
    }>();
    return {
      address: this.address,
      question: info.question,
      outcomeCount: Number(info.outcomeCount),
      closeTime: new Date(Number(info.closeTime) * 1000),
      createTime: new Date(Number(info.createTime)),
      closedAt: info.closedAt > 0 ? new Date(Number(info.closedAt)) : null,
    };
  }

  public async getFullInfo(): Promise<MarketInfoFull> {
    const info = await this.getInfo();
    const outcomes = await this.getOutcomes();
    const outcomePrices = await this.getOutcomePrices();
    const feeBPS = await this.getFeeBPS();
    const resolveDelay = await this.contract.methods.resolveDelay().call<bigint>();
    const resolvedOutcomeIndex = await this.getResolvedOutcome();
    const creator = await this.contract.methods.creator().call<string>();
    const oracle = await this.contract.methods.oracle().call<string>();
    const marketAMM = await this.contract.methods.marketAMM().call<string>();

    return {
      ...info,
      outcomeNames: outcomes.map(outcome => outcome.name),
      outcomePrices,
      feeBPS: Number(feeBPS),
      state: await this.getMarketState(),
      resolveDelay: Number(resolveDelay),
      resolved: resolvedOutcomeIndex !== null,
      resolvedOutcomeIndex: resolvedOutcomeIndex ? Number(resolvedOutcomeIndex) : null,
      creator,
      oracle,
      marketAMM,
    };
  }

  public async getPoolData(): Promise<MarketPoolData> {
    const poolData = await this.contract.methods.getPoolData().call();

    const outcomes: Outcome[] = poolData.outcomes.map(outcome => ({
      name: outcome.name,
      shares: {
        total: outcome.shares.total as bigint,
        available: outcome.shares.available as bigint,
      },
    }));

    return {
      balance: poolData.balance as bigint,
      liquidity: poolData.liquidity as bigint,
      totalAvailableShares: poolData.totalAvailableShares as bigint,
      outcomes,
    };
  }

  public async getOutcomes(): Promise<Outcome[]> {
    const outcomes = await this.contract.methods.getOutcomes().call<{
      names: string[];
      totalShares: MatchPrimitiveType<Uint256, bigint>[];
      poolShares: MatchPrimitiveType<Uint256, bigint>[];
    }>();

    return outcomes.names.map((name, index) => ({
      name,
      shares: {
        total: outcomes.totalShares[index],
        available: outcomes.poolShares[index],
      },
    }));
  }

  public async getMarketState(): Promise<MarketState> {
    const state = await this.contract.methods.state().call<bigint>();
    return this._parseMarketState(state);
  }

  public async getUserOutcomeShares(user: string): Promise<bigint[]> {
    const marketInfo = await this.getInfo();

    const outcomeShares: bigint[] = [];
    for (let i = 0n; i < marketInfo.outcomeCount; i++) {
      const shares = await this.contract.methods.getUserOutcomeShares(user, i).call<bigint>();
      outcomeShares.push(shares);
    }

    return outcomeShares;
  }

  public async getUserLiquidityShares(user: string): Promise<bigint> {
    return await this.contract.methods.getUserLiquidityShares(user).call<bigint>();
  }

  public async getUserClaimableFees(user: string): Promise<bigint> {
    return await this.contract.methods.getClaimableFees(user).call<bigint>();
  }

  public async getUserClaimedFees(user: string): Promise<bigint> {
    return await this.contract.methods.getUserClaimedFees(user).call<bigint>();
  }

  public async getUserFeeState(user: string): Promise<MarketUserFeeState> {
    return {
      claimable: await this.getUserClaimableFees(user),
      claimed: await this.getUserClaimedFees(user),
    };
  }

  public async getUserPositions(user: string): Promise<MarketUserPosition[]> {
    const { outcomeCount } = await this.getInfo();
    const outcomePrices = await this.getOutcomePrices();

    const buyEvents = (await this.contract.getPastEvents('SharesBought', {
      filter: { _buyer: user },
      fromBlock: this.startBlock || 0,
      toBlock: 'latest',
    })) as EventLog[];

    const sellEvents = (await this.contract.getPastEvents('SharesSold', {
      filter: { _seller: user },
      fromBlock: this.startBlock || 0,
      toBlock: 'latest',
    })) as EventLog[];

    const positions: MarketUserPosition[] = Array.from(
      { length: Number(outcomeCount) },
      (_, i) => ({
        outcomeIndex: i,
        shares: 0n,
        avgEntryPrice: 0,
        pnl: 0n,
        pnlPercentage: 0,
        realizedPnl: 0n,
        realizedPnlPercentage: 0,
        currentPrice: outcomePrices[i],
        currentSharesValue: 0n,
      }),
    );

    // PNL = ((Partial closing volume + (current price * position quantity)) - open volume)
    const outcomeToSharesBought: bigint[] = Array(Number(outcomeCount)).fill(0n);

    const outcomeToClosingVolume: bigint[] = Array(Number(outcomeCount)).fill(0n);
    const outcomeToOpenVolume: bigint[] = Array(Number(outcomeCount)).fill(0n);

    for (const sellEvent of sellEvents) {
      const outcomeIndex = Number(sellEvent.returnValues._outcomeIndex as bigint);
      const amount = sellEvent.returnValues._amount as bigint;
      const shares = sellEvent.returnValues._shares as bigint;

      outcomeToClosingVolume[outcomeIndex] += amount;
      positions[outcomeIndex].shares -= shares;
    }

    for (const buyEvent of buyEvents) {
      const outcomeIndex = Number(buyEvent.returnValues._outcomeIndex as bigint);
      const amount = buyEvent.returnValues._amount as bigint;
      const fee = buyEvent.returnValues._fee as bigint;
      const amountAfterFee = amount - fee;
      const shares = buyEvent.returnValues._shares as bigint;

      outcomeToSharesBought[outcomeIndex] += shares;
      outcomeToOpenVolume[outcomeIndex] += amountAfterFee;
      positions[outcomeIndex].shares += shares;
    }

    for (let i = 0; i < outcomeCount; i++) {
      positions[i].currentSharesValue = await this.getUserSharesValue(user, i);
      positions[i].currentPrice = outcomePrices[i];

      positions[i].pnl =
        outcomeToClosingVolume[i] + positions[i].currentSharesValue - outcomeToOpenVolume[i];
      positions[i].pnlPercentage =
        outcomeToOpenVolume[i] > 0n
          ? (Number(positions[i].pnl) / Number(outcomeToOpenVolume[i])) * 100
          : 0;

      positions[i].avgEntryPrice =
        outcomeToSharesBought[i] > 0n
          ? Number((outcomeToOpenVolume[i] * ONE) / outcomeToSharesBought[i]) / Number(ONE)
          : 0;
    }

    return positions;
  }

  public async getUserSharesValue(user: string, outcomeIndex: bigint | number): Promise<bigint> {
    const userShares = await this.getUserOutcomeShares(user);
    const outcomePrice = await this._getOutcomePriceRaw(outcomeIndex);

    return (userShares[Number(outcomeIndex)] * outcomePrice) / ONE;
  }

  public async getOutcomePrice(outcomeIndex: bigint | number): Promise<number> {
    return Number(await this._getOutcomePriceRaw(outcomeIndex)) / Number(ONE);
  }

  public async getOutcomePrices(): Promise<number[]> {
    const { outcomeCount } = await this.getInfo();
    const outcomePrices: number[] = [];
    for (let i = 0n; i < outcomeCount; i++) {
      outcomePrices.push(await this.getOutcomePrice(i));
    }
    return outcomePrices;
  }

  public async getResolutionData(): Promise<MarketResolutionData> {
    const resolvedOutcome = await this.getResolvedOutcome();
    const resolveDelay = await this.contract.methods.resolveDelay().call<bigint>();

    return {
      resolved: resolvedOutcome !== null,
      resolvedOutcomeIndex: resolvedOutcome,
      resolveDelay,
    };
  }

  public async getResolvedOutcome(): Promise<bigint | null> {
    try {
      return await this.contract.methods.getResolvedOutcome().call<bigint>();
    } catch {
      return null;
    }
  }

  public async getFeeBPS(): Promise<bigint> {
    return await this.contract.methods.getFeeBPS().call<bigint>();
  }

  public async calcBuyShares(
    amount: bigint | number,
    outcomeIndex: bigint | number,
  ): Promise<bigint> {
    amount = BigInt(`${amount}`);
    const marketAMMAddress = await this.contract.methods.marketAMM().call<string>();
    const marketAMM = MarketAMM.forAddress(marketAMMAddress, this.connection);
    const feeBPS = await this.getFeeBPS();
    const fee = (amount * feeBPS) / BPS;
    const poolData = await this.getPoolData();

    const shares = await marketAMM.getBuyShares(
      amount - fee,
      outcomeIndex,
      poolData.liquidity,
      poolData.outcomes.map(outcome => outcome.shares.available),
    );

    return shares as bigint;
  }

  public async calcSellShares(
    amount: bigint | number,
    outcomeIndex: bigint | number,
  ): Promise<bigint> {
    amount = BigInt(`${amount}`);
    const marketAMMAddress = await this.contract.methods.marketAMM().call<string>();
    const marketAMM = MarketAMM.forAddress(marketAMMAddress, this.connection);
    const poolData = await this.getPoolData();

    const shares = await marketAMM.getSellShares(
      amount,
      outcomeIndex,
      poolData.liquidity,
      poolData.outcomes.map(outcome => outcome.shares.available),
    );

    return shares as bigint;
  }

  private async _getOutcomePriceRaw(outcomeIndex: bigint | number): Promise<bigint> {
    return await this.contract.methods.getOutcomePrice(outcomeIndex).call<bigint>();
  }

  private _parseMarketState(state: bigint): MarketState {
    switch (state) {
      case 0n:
        return MarketState.Open;
      case 1n:
        return MarketState.Closed;
      case 2n:
        return MarketState.Resolved;
      default:
        throw new Error(`Invalid market state: ${state}`);
    }
  }
}

export default Market;
