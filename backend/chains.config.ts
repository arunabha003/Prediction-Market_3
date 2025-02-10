import { type ChainConfig } from '@common/types';

import { ConfigService } from '@nestjs/config';

import { Chain } from '@common/types';

export const getChains = (configService: ConfigService): ChainConfig => {
  const chainConfig: ChainConfig = {
    [Chain.Ethereum]: {
      rpcUrl: configService.get<string>('ETHEREUM_RPC_URL'),
      chainId: 1,
    },
    [Chain.Polygon]: {
      rpcUrl: configService.get<string>('POLYGON_RPC_URL'),
      chainId: 137,
    },
    [Chain.Sepolia]: {
      rpcUrl: configService.get<string>('SEPOLIA_RPC_URL'),
      chainId: 11155111,
    },
    [Chain.Local]: {
      rpcUrl: 'http://localhost:8545',
      chainId: 31337,
    },
  };

  for (const [chainName, config] of Object.entries(chainConfig)) {
    if (!config.rpcUrl) {
      delete chainConfig[chainName];
    }
  }

  return chainConfig;
};
