import { Test, TestingModule } from '@nestjs/testing';

import { UsersController } from './users.controller';
import { UserMarketService } from './services';

describe('MarketsController', () => {
  let usersController: UsersController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [UserMarketService],
    }).compile();

    usersController = app.get<UsersController>(UsersController);
  });

  describe('Get User Markets', () => {
    it('should return all markets for user', () => {
      expect(usersController.getUserMarkets('1')).resolves.toEqual({
        markets: [
          {
            id: '0x789...',
            title: 'Created by User Market',
            chain: 'ethereum',
            status: 'active',
            volume: '5000 USDC',
          },
        ],
      });
    });
  });

  describe('Get User Positions', () => {
    it('should return all positions for user', () => {
      expect(usersController.getUserPositions('1')).resolves.toEqual({
        positions: [
          {
            marketId: '0x123...',
            outcome: 'Yes',
            amount: '100 USDC',
            entryPrice: '0.65',
            currentPrice: '0.75',
            pnl: '+15.38%',
          },
          {
            marketId: '0x456...',
            outcome: 'No',
            amount: '200 USDC',
            entryPrice: '0.45',
            currentPrice: '0.40',
            pnl: '-11.11%',
          },
        ],
      });
    });
  });
});
