import { Test, TestingModule } from '@nestjs/testing';

import { MarketsController } from './markets.controller';
import { MarketsService } from './services';

describe('MarketsController', () => {
  let marketsController: MarketsController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [MarketsController],
      providers: [MarketsService],
    }).compile();

    marketsController = app.get<MarketsController>(MarketsController);
  });

  describe('Create Market', () => {
    it('should return created market data', () => {
      expect(
        marketsController.createMarket({ params: 'test' }),
      ).resolves.toEqual({
        success: true,
        marketId: '0x123...',
        chain: 'ethereum',
        details: {
          title: 'Sample Market',
          outcomes: ['Yes', 'No'],
          endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
          liquidity: '1000 USDC',
        },
      });
    });
  });

  describe('Get Markets', () => {
    it('should return all available markets', () => {
      expect(marketsController.getMarkets()).resolves.toEqual({
        markets: [
          {
            id: '0x123...',
            title: 'Will BTC reach 100k in 2024?',
            chain: 'ethereum',
            outcomes: ['Yes', 'No'],
            endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
            liquidity: '1000 USDC',
          },
          {
            id: '0x456...',
            title: 'Will ETH 2.0 launch in Q2 2024?',
            chain: 'polygon',
            outcomes: ['Yes', 'No'],
            endDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            liquidity: '2000 USDC',
          },
        ],
      });
    });
  });
});
