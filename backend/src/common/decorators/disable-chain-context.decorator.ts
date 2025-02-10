import { SetMetadata } from '@nestjs/common';

export const DISABLE_CHAIN_CONTEXT = 'DISABLE_CHAIN_CONTEXT';
export const DisableChainContext = () =>
  SetMetadata(DISABLE_CHAIN_CONTEXT, true);
