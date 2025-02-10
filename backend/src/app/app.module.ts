import { APP_INTERCEPTOR } from '@nestjs/core';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { ContractsModule, Web3Module } from '@utils';
import { MarketsModule } from '../markets/markets.module';
import { UsersModule } from '../users/users.module';

import { AppController } from './app.controller';

import { AppService } from './app.service';

import { validate } from '../env.validation';

import { ChainContextInterceptor } from '@interceptors';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, // Makes ConfigModule available globally
      validate,
    }),
    Web3Module,
    ContractsModule,
    MarketsModule,
    UsersModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_INTERCEPTOR,
      useClass: ChainContextInterceptor,
    },
  ],
})
export class AppModule {}
