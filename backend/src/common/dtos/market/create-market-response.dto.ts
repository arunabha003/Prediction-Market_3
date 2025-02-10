import { MarketInfoFull } from '@prediction-markets/sdk';

export class CreateMarketResponseDto {
  address: string;
  marketInfo: MarketInfoFull;
}
