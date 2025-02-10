import type { Request } from 'express';

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const ChainContext = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest<Request>();
    return request.chainContext;
  },
);
