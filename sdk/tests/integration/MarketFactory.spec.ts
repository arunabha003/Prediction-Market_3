import { utils } from 'web3';

import { AnvilConnection } from '../../src/Connection';

import { Market, MarketAMM, MarketFactory, CentralizedOracle } from '../../src/Contracts';

describe('MarketFactory', () => {
  let marketFactory: MarketFactory;
  let connection: AnvilConnection;
  let owner: string;

  beforeAll(async () => {
    connection = new AnvilConnection();

    const web3 = connection.getWeb3();
    const accounts = await web3.eth.getAccounts();
    owner = accounts[0];

    const marketImplementation = await Market.deployImplementation(connection, owner);
    const marketAMMImplementation = await MarketAMM.deployImplementation(connection, owner);
    const defaultOracleImplementation = await CentralizedOracle.deployImplementation(connection);

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
  });

  describe('deploy', () => {
    test('Correctly deploys a Market factory', async () => {
      const marketFactoryOwner = await marketFactory.getOwner();
      const marketCount = await marketFactory.getMarketCount();

      expect(marketFactoryOwner).toBe(owner);
      expect(marketCount).toBe(0n);

      const marketFactoryImplementation = await marketFactory.getImplementation();

      const marketFactoryImpl = MarketFactory.forAddress(marketFactoryImplementation, connection);
      const implementationOwner = await marketFactoryImpl.getOwner();
      expect(implementationOwner).toBe('0x0000000000000000000000000000000000000000');
    });
  });

  describe('createMarket', () => {
    test('Correctly creates a market', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      const market = await marketFactory.createMarket({
        question,
        outcomeNames,
        closeTime,
        oracle,
        initialLiquidity,
        resolveDelaySeconds,
        feeBPS,
      });

      const marketCount = await marketFactory.getMarketCount();
      expect(marketCount).toBe(1n);

      const markets = await marketFactory.getMarkets();
      expect(markets.length).toBe(1);

      const firstMarket = await marketFactory.getMarket(0);
      expect(firstMarket.address).toBe(market.address);
    });

    test('Throws if question is too short', async () => {
      const question = '42';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Question must be longer than 6 characters');
    });

    test('Throws if outcomeNames is not binary', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42', 'Maybe'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Only binary markets are supported');
    });

    test('Throws if closeTime is in the past', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) - 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Close time must be greater than current time');
    });

    test('Throws if initialLiquidity is negative', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = -1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Initial liquidity must be greater than 0');
    });

    test('Throws if resolveDelaySeconds is less than 60', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 59;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Resolve delay must be greater than 1 minute and less than 7 days');
    });

    test('Throws if resolveDelaySeconds is greater than 604800', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 604801;
      const feeBPS = 100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Resolve delay must be greater than 1 minute and less than 7 days');
    });

    test('Throws if feeBPS is negative', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = -100;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Fee BPS must be between 0 and 10000');
    });

    test('Throws if feeBPS is greater than 10000', async () => {
      const question = 'What is the meaning of life?';
      const outcomeNames = ['42', 'Not 42'];
      const closeTime = Math.floor(Date.now() / 1000) + 60;
      const oracle = owner;
      const initialLiquidity = 1000n;
      const resolveDelaySeconds = 60;
      const feeBPS = 10001;

      await expect(
        marketFactory.createMarket({
          question,
          outcomeNames,
          closeTime,
          oracle,
          initialLiquidity,
          resolveDelaySeconds,
          feeBPS,
        }),
      ).rejects.toThrow('Fee BPS must be between 0 and 10000');
    });
  });

  describe('transferOwnership', () => {
    test('Correctly transfers ownership', async () => {
      const newOwner = utils.randomHex(20);

      await marketFactory.transferOwnership(newOwner);
      const owner = await marketFactory.getOwner();

      expect(owner.toLocaleLowerCase()).toBe(newOwner.toLocaleLowerCase());
    });
  });

  describe('getMarkets', () => {
    test('Correctly returns markets', async () => {
      const markets = await marketFactory.getMarkets();
      expect(markets.length).toBe(1);
    });
  });

  describe('getUserCreatedMarkets', () => {
    test('Correctly returns user created markets', async () => {
      const user = owner;

      const markets = await marketFactory.getUserCreatedMarkets(user);
      expect(markets.length).toBe(1);
    });

    test('Correctly returns user created markets for another user', async () => {
      const user = utils.randomHex(20);

      const markets = await marketFactory.getUserCreatedMarkets(user);
      expect(markets.length).toBe(0);
    });
  });

  /// ...
});
