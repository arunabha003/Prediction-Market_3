import { Module } from '@nestjs/common';

import { UsersController } from './users.controller';

import { UserMarketService } from './services';

@Module({
  controllers: [UsersController],
  providers: [UserMarketService],
})
export class UsersModule {}
