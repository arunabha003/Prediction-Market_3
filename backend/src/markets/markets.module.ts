import { Module } from '@nestjs/common';

import { MarketsController } from './markets.controller';

import { MarketsService } from './services';

@Module({
  controllers: [MarketsController],
  providers: [MarketsService],
})
export class MarketsModule {}
