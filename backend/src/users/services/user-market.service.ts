import type { Position, UserMarket } from '@common/types';

import { Injectable, Logger } from '@nestjs/common';

import { marketContractAbi } from '@abis';
import { Web3Service } from '@utils/web3';

@Injectable()
export class UserMarketService {
  private readonly logger = new Logger(UserMarketService.name);

  constructor(private web3Service: Web3Service) {}

  async getUserMarkets(userId: string): Promise<{ markets: UserMarket[] }> {
    this.logger.log('Fetching User markets...');

    return {
      markets: [
        {
          id: '0x789...',
          title: 'Created by User Market',
          chain: 'ethereum',
          status: 'active',
          volume: '5000 USDC',
        },
      ],
    };
  }

  async getUserPositions(userId: string): Promise<{ positions: Position[] }> {
    this.logger.log('Fetching User positions...');

    return {
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
    };
  }
}
