import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getRoot() {
    return true;
  }
}
