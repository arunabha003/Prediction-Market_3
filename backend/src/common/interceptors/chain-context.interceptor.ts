import type { Request } from 'express';
import { Chain } from '@common/types';

import { Reflector } from '@nestjs/core';
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Observable } from 'rxjs';

import { DISABLE_CHAIN_CONTEXT } from '@decorators';

import { getChains } from '@/chains.config';

@Injectable()
export class ChainContextInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    private configService: ConfigService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<Request>();
    const chainId = request.query.chainId;

    const disableChainContext = this.reflector.get<boolean>(
      DISABLE_CHAIN_CONTEXT,
      context.getHandler(),
    );

    if (disableChainContext) {
      return next.handle();
    }

    if (!chainId) {
      throw new BadRequestException('chainId is required');
    }

    const CHAINS = getChains(this.configService);
    const chainEntry = Object.entries(CHAINS).find(
      ([, config]) => config.chainId === Number(chainId),
    );

    if (!chainEntry) {
      throw new BadRequestException(`Unsupported chainId: ${chainId}`);
    }

    const [chainName, chainConfig] = chainEntry;

    request.chainContext = {
      chainId: Number(chainId),
      chainName: chainName as Chain,
      rpcUrl: chainConfig.rpcUrl,
      // Add any other chain-specific context you need
    };

    return next.handle();
  }
}
