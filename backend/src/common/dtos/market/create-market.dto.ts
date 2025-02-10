import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

import { IsEthereumAddress } from '@utils/validation';
import { Optional } from '@nestjs/common';

export class CreateMarketDto {
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  question: string;

  @IsArray()
  @IsString({ each: true })
  @ArrayMinSize(2)
  @ArrayMaxSize(2)
  outcomeNames: string[];

  @IsNotEmpty()
  @IsNumber()
  closeTime: number;

  @Optional()
  @IsEthereumAddress()
  oracle: string;

  @IsNotEmpty()
  @IsString()
  initialLiquidity: string;

  @IsNotEmpty()
  @IsNumber()
  resolveDelaySeconds: number;

  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  @Max(10000)
  feeBPS: number;
}
