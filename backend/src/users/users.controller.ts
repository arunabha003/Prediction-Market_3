import { Controller, Get, Param } from '@nestjs/common';

import { UserMarketService } from './services';

@Controller('api/users')
export class UsersController {
  constructor(private readonly userMarketService: UserMarketService) {}

  @Get(':userId/positions')
  getUserPositions(@Param('userId') userId: string) {
    return this.userMarketService.getUserPositions(userId);
  }

  @Get(':userId/markets')
  getUserMarkets(@Param('userId') userId: string) {
    return this.userMarketService.getUserMarkets(userId);
  }
}
