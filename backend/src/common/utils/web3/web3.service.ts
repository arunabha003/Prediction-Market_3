import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { HttpConnection } from '@prediction-markets/sdk';

import { getChains } from '@/chains.config';

@Injectable()
export class Web3Service implements OnModuleInit {
  private readonly logger = new Logger(Web3Service.name);
  private connectionInstances: Map<number, HttpConnection> = new Map();

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    const privateKey =
      this.configService.getOrThrow<string>('WALLET_PRIVATE_KEY');

    // Initialize Connection instance for each chain
    const CHAINS = getChains(this.configService);
    for (const chain of Object.values(CHAINS)) {
      const connection = new HttpConnection(chain.rpcUrl);
      connection.addAccount(privateKey);

      this.connectionInstances.set(chain.chainId, connection);

      await this.validateChainId(chain.chainId, chain.rpcUrl);
    }
  }

  getConnection(chainId: number): HttpConnection {
    const connection = this.connectionInstances.get(chainId);
    if (!connection) {
      throw new Error(`Connection not initialized for chain ${chainId}`);
    }
    return connection;
  }

  private async validateChainId(chainId: number, rpcUrl: string) {
    const connection = this.getConnection(chainId);
    const configChainId = BigInt(chainId.toString());

    try {
      const actualChainId = await connection.getWeb3().eth.getChainId();
      if (actualChainId !== configChainId) {
        throw new Error(
          `Chain ID mismatch for chain ${chainId}. Expected ${actualChainId} from the network, but got ${chainId} from the configuration`,
        );
      }
    } catch (error) {
      this.logger.error(
        `Failed to validate chain ID for chain ${chainId} with RPC URL: ${rpcUrl}`,
        error,
      );
      throw error;
    }
  }
}
