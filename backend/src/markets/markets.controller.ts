import type { IChainContext } from '@common/types';

import {
  Controller,
  Post,
  Get,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';

import { ChainContext } from '@decorators';
import { CreateMarketDto, GetMarketsDto } from '@dtos';

import { MarketsService } from './services';

@Controller('api/markets')
export class MarketsController {
  constructor(private readonly marketService: MarketsService) {}

  @Get()
  @HttpCode(HttpStatus.OK)
  getMarkets(
    @ChainContext() chainContext: IChainContext,
  ): Promise<GetMarketsDto> {
    return this.marketService.getMarkets(chainContext.chainId);
  }

  @Post('create-market')
  @HttpCode(HttpStatus.OK)
  createMarket(
    @ChainContext() chainContext: IChainContext,
    @Body() marketData: CreateMarketDto,
  ) {
    return this.marketService.createMarket(chainContext.chainId, marketData);
  }
}
