import { MarketInfoFull } from '@prediction-markets/sdk';

export class GetMarketsDto {
  markets: {
    [address: string]: MarketInfoFull;
  };
}
