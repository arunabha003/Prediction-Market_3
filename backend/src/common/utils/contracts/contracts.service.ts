import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { Market, MarketFactory } from '@prediction-markets/sdk';

import { Web3Service } from '@utils/web3';

@Injectable()
export class ContractsService {
  private readonly logger = new Logger(ContractsService.name);

  constructor(
    private configService: ConfigService,
    private web3Service: Web3Service,
  ) {}

  getMarketFactory(chainId: number): MarketFactory {
    const marketFactoryAddress = this.configService.getOrThrow<string>(
      'MARKET_FACTORY_ADDRESS',
    );

    const connection = this.web3Service.getConnection(chainId);

    return MarketFactory.forAddress(marketFactoryAddress, connection);
  }

  getMarket(chainId: number, address: string): Market {
    const connection = this.web3Service.getConnection(chainId);
    return Market.forAddress(address, connection);
  }
}
