import { IChainContext } from '@common/types';

declare global {
  namespace Express {
    export interface Request {
      chainContext: IChainContext;
    }
  }
}
