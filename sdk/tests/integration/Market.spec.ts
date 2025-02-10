import { utils } from 'web3';

import { AnvilConnection } from '../../src/Connection';

import { Market, MarketAMM, MarketFactory, CentralizedOracle } from '../../src/Contracts';
import { MarketState } from '../../src/types';

/**
 * @description Stateful integration tests for the Market class
 */
describe('Market', () => {
  let connection: AnvilConnection;

  let owner: string;
  let bob: string;
  let alice: string;

  let marketImplementation: string;
  let marketAMMImplementation: string;
  let defaultOracleImplementation: string;

  let marketFactory: MarketFactory;
  let market: Market;

  beforeAll(async () => {
    connection = new AnvilConnection();

    const web3 = connection.getWeb3();
    const accounts = await web3.eth.getAccounts();
    owner = accounts[0];
    bob = accounts[1];
    alice = accounts[2];

    marketImplementation = await Market.deployImplementation(connection, owner);
    marketAMMImplementation = await MarketAMM.deployImplementation(connection, owner);
    defaultOracleImplementation = await CentralizedOracle.deployImplementation(connection);

    marketFactory = await MarketFactory.deploy(
      connection,
      {
        owner,
        marketImplementation,
        marketAMMImplementation,
        defaultOracleImplementation,
      },
      owner,
    );

    const question = 'What is the meaning of life?';
    const outcomeNames = ['42', 'Not 42'];
    const closeTime = Math.floor(Date.now() / 1000) + 999999;
    const initialLiquidity = BigInt(utils.toWei('1000', 'ether'));
    const resolveDelaySeconds = 60;
    const feeBPS = 100;

    market = await marketFactory.createMarket(
      {
        question,
        outcomeNames,
        closeTime,
        oracle: '0x0000000000000000000000000000000000000000',
        initialLiquidity,
        resolveDelaySeconds,
        feeBPS,
      },
      owner,
    );
  });

  describe('addLiquidity', () => {
    test('Correctly adds liquidity to the market', async () => {
      const amount = BigInt(utils.toWei('100', 'ether'));

      const { liquidityShares, outcomeShares } = await market.addLiquidity(
        {
          amount: BigInt(utils.toWei('100', 'ether')),
          deadline: Math.floor(Date.now() / 1000) + 100,
        },
        bob,
      );

      expect(liquidityShares).toBe(amount);
      expect(outcomeShares).toEqual([0n, 0n]);
    });

    //... To add more tests
  });

  describe('removeLiquidity', () => {
    test('Correctly removes liquidity from the market', async () => {
      const shares = BigInt(utils.toWei('100', 'ether'));

      await market.addLiquidity(
        { amount: shares, deadline: Math.floor(Date.now() / 1000) + 100 },
        bob,
      );

      const { amount, outcomeShares } = await market.removeLiquidity(
        { shares, deadline: Math.floor(Date.now() / 1000) + 100 },
        bob,
      );

      expect(amount.weiBigInt).toBe(shares);
      expect(outcomeShares).toEqual([0n, 0n]);
    });

    //... To add more tests
  });

  let buyAmountAfterFee: bigint;
  let aliceShares: bigint;

  describe('buyShares', () => {
    test('Correctly buys shares from the market', async () => {
      const amount = BigInt(utils.toWei('100', 'ether'));
      const outcomeIndex = 0;
      const minOutcomeShares = 0;
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 100);

      const calculatedShares = await market.calcBuyShares(amount, outcomeIndex);

      const { sharesBought, executedPrice, fee } = await market.buyShares(
        {
          amount,
          outcomeIndex,
          minOutcomeShares,
          deadline,
        },
        alice,
      );
      buyAmountAfterFee = amount - fee.weiBigInt;
      aliceShares = sharesBought;

      expect(calculatedShares).toBe(sharesBought);
      expect(sharesBought).toBeGreaterThan(amount);
      expect(executedPrice).toBeGreaterThan(0n);
      expect(executedPrice).toBeLessThan(BigInt(utils.toWei('1', 'ether')));
    });

    //... To add more tests
  });

  describe('sellShares', () => {
    test('Correctly sells shares to the market', async () => {
      const outcomeIndex = 0;
      const maxOutcomeShares = BigInt(utils.toWei('999', 'ether'));
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 100);

      const calculatedShares = await market.calcSellShares(buyAmountAfterFee, outcomeIndex);

      const { receivedAmount, sharesSold, fee, executedPrice } = await market.sellShares(
        {
          receivedAmount: buyAmountAfterFee,
          outcomeIndex,
          maxOutcomeShares,
          deadline,
        },
        alice,
      );

      expect(receivedAmount.weiBigInt).toBe(buyAmountAfterFee - fee.weiBigInt);
      expect(sharesSold).toBe(aliceShares);
      expect(calculatedShares).toBe(sharesSold);
      expect(executedPrice).toBeGreaterThan(0n);
      expect(executedPrice).toBeLessThan(BigInt(utils.toWei('1', 'ether')));
    });

    //... To add more tests
  });

  describe('claimFees', () => {
    test('Correctly claims the fees', async () => {
      const { amount } = await market.claimFees(owner);

      expect(amount.weiBigInt).toBeGreaterThan(0n);
    });

    //... To add more tests
  });

  let closableMarket: Market;

  describe('closeMarket', () => {
    beforeAll(async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 1;
      const initialLiquidity = BigInt(utils.toWei('1000', 'ether'));
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      closableMarket = await marketFactory.createMarket(
        {
          question,
          outcomeNames,
          closeTime,
          oracle: '0x0000000000000000000000000000000000000000',
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        },
        owner,
      );
    });

    test('Correctly closes the market', async () => {
      await new Promise(resolve => setTimeout(resolve, 2000));

      await closableMarket.closeMarket(owner);

      const info = await closableMarket.getInfo();

      expect(info.closedAt?.getTime()).toBeGreaterThan(0);
    });

    test('Throws when the market cannot be closed', async () => {
      await expect(() => market.closeMarket(owner)).rejects.toThrow(
        'Market close time has not passed',
      );
    });

    //... To add more tests
  });

  describe('resolveMarket', () => {
    test('Throws when the market is not closed', async () => {
      await expect(() => market.resolveMarket(owner)).rejects.toThrow('Invalid market state');
    });

    //... To add more tests
  });

  describe('claimLiquidity', () => {
    test('Throw error when market is not resolved', async () => {
      await expect(() => market.claimLiquidity(owner)).rejects.toThrow('Invalid market state');
    });

    //... To add more tests
  });

  describe('claimRewards', () => {
    test('Throw error when market is not resolved', async () => {
      await expect(() => market.claimRewards(owner)).rejects.toThrow('Invalid market state');
    });
  });

  describe('getInfo', () => {
    test('Correctly retrieves the market info', async () => {
      const info = await market.getInfo();

      expect(info.question).toBe('What is the meaning of life?');
      expect(info.outcomeCount).toBe(2);
      expect(info.closeTime.getTime()).toBeGreaterThan(0);
      expect(info.createTime.getTime()).toBeGreaterThan(0);
      expect(info.closedAt).toBe(null);
    });
  });

  describe('getFullInfo', () => {
    test('Correctly retrieves the full market info', async () => {
      const fullInfo = await market.getFullInfo();

      expect(fullInfo.question).toBe('What is the meaning of life?');
      expect(fullInfo.outcomeCount).toBe(2);
      expect(fullInfo.closeTime.getTime()).toBeGreaterThan(0);
      expect(fullInfo.createTime.getTime()).toBeGreaterThan(0);
      expect(fullInfo.closedAt).toBe(null);
      expect(fullInfo.feeBPS).toBe(100);
      expect(fullInfo.state).toBe(MarketState.Open);
      expect(fullInfo.resolveDelay).toBe(60);
      expect(fullInfo.resolved).toBe(false);
      expect(fullInfo.resolvedOutcomeIndex).toBe(null);
      expect(fullInfo.creator).toBe(owner);
    });
  });

  describe('getOutcomes', () => {
    test('Correctly retrieves the market outcomes', async () => {
      const outcomes = await market.getOutcomes();

      expect(outcomes).toEqual([
        {
          name: '42',
          shares: {
            total: expect.any(BigInt),
            available: expect.any(BigInt),
          },
        },
        {
          name: 'Not 42',
          shares: {
            total: expect.any(BigInt),
            available: expect.any(BigInt),
          },
        },
      ]);
    });
  });

  describe('getUserLiquidityShares', () => {
    test('Correctly retrieves the user liquidity shares', async () => {
      const liquidityShares = await market.getUserLiquidityShares(bob);

      expect(liquidityShares).toBe(BigInt(utils.toWei('100', 'ether')));
    });
  });
});
