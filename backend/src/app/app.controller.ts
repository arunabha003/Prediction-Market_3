import { Controller, Get, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';

import { AppService } from './app.service';

import { DisableChainContext } from '@decorators';

@ApiTags('Health Check')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @ApiOperation({
    summary: 'Perform a basic health check',
    description:
      'An endpoint for a basic health check. It will be replaced with a more detailed health check in the future.',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Returns true if the API is running',
    type: Boolean,
  })
  @Get()
  @HttpCode(HttpStatus.OK)
  @DisableChainContext()
  getRoot(): boolean {
    return this.appService.getRoot();
  }
}
