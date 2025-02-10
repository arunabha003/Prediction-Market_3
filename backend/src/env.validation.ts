import { plainToInstance } from 'class-transformer';
import {
  IsHexadecimal,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
  validateSync,
} from 'class-validator';

import { IsEthereumAddress } from '@utils/validation';

class EnvironmentVariables {
  @IsEthereumAddress()
  MARKET_FACTORY_ADDRESS: string;

  @IsHexadecimal()
  @MinLength(2)
  WALLET_PRIVATE_KEY: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(65535)
  PORT: number;

  @IsOptional()
  @IsString()
  CLIENT: string;

  @IsOptional()
  @IsString()
  ETHEREUM_RPC_URL: string;

  @IsOptional()
  @IsString()
  SEPOLIA_RPC_URL: string;

  @IsOptional()
  @IsString()
  POLYGON_RPC_URL: string;
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    const constraints = errors.map((e) => Object.values(e.constraints)).flat();
    const message = `Environment validation failed:\n${constraints.join('\n')}\n`;
    throw new Error(message);
  }
  return validatedConfig;
}
