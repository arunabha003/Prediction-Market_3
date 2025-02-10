import { Injectable, Logger } from '@nestjs/common';
import { MarketInfoFull } from '@prediction-markets/sdk';

import { CreateMarketDto, CreateMarketResponseDto, GetMarketsDto } from '@dtos';

import { ContractsService } from '@utils/contracts';

@Injectable()
export class MarketsService {
  private readonly logger = new Logger(MarketsService.name);

  constructor(private contractService: ContractsService) {}

  async createMarket(
    chainId: number,
    createMarketDto: CreateMarketDto,
  ): Promise<CreateMarketResponseDto> {
    this.logger.log('MarketsService createMarket() called.');

    try {
      const marketFactory = this.contractService.getMarketFactory(chainId);

      const market = await marketFactory.createMarket({
        question: createMarketDto.question,
        outcomeNames: createMarketDto.outcomeNames,
        closeTime: createMarketDto.closeTime,
        oracle: createMarketDto.oracle,
        initialLiquidity: createMarketDto.initialLiquidity,
        resolveDelaySeconds: createMarketDto.resolveDelaySeconds,
        feeBPS: createMarketDto.feeBPS,
      });

      this.logger.log(`Market created: ${market.address}`);

      const marketInfo = await market.getFullInfo();

      return {
        address: market.address,
        marketInfo,
      };
    } catch (error) {
      this.logger.error('Error in create market:', error);
      throw error;
    }
  }

  async getMarkets(chainId: number): Promise<GetMarketsDto> {
    this.logger.log('MarketsService getMarkets() called.');
    this.logger.log('Fetching markets from the Market Factory...');

    try {
      const marketFactory = this.contractService.getMarketFactory(chainId);
      const markets = await marketFactory.getMarkets();

      const marketInfos = await Promise.all<MarketInfoFull>(
        markets.map((market) => market.getFullInfo()),
      );

      const result = marketInfos.reduce((acc, marketInfo) => {
        acc[marketInfo.address] = marketInfo;
        return acc;
      }, {});

      this.logger.log(
        'Successfully fetched actual markets from the smart contract',
      );

      return {
        markets: result,
      };
    } catch (error) {
      this.logger.error(
        'Error fetching actual markets from the smart contract:',
        error,
      );
      throw error;
    }
  }
}
