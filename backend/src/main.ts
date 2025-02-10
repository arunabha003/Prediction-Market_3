import type { NestExpressApplication } from '@nestjs/platform-express';

import { NestFactory } from '@nestjs/core';

import { AppModule } from './app/app.module';
import { setupApp, setupSwagger } from './setup-app';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  setupApp(app);
  setupSwagger(app);

  await app.listen(process.env.PORT ?? 3500);
}
bootstrap();
