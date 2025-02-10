import { TransactionRevertInstructionError } from 'web3';

import marketFactoryAbi from '../abi/marketFactory';
import marketAMMAbi from '../abi/marketAMM';
import marketAbi from '../abi/market';
import centralizedOracleAbi from '../abi/centralizedOracle';

import { decodeErrorData } from '../utils';

import MarketErrors from './Market/MarketErrors';
import MarketAMMErrors from './MarketAMM/MarketAMMErrors';
import MarketFactoryErrors from './MarketFactory/MarketFactoryErrors';
import CentralizedOracleErrors from './CentralizedOracle/CentralizedOracleErrors';

const ContractsErrors = {
  ...MarketErrors,
  ...MarketAMMErrors,
  ...MarketFactoryErrors,
  ...CentralizedOracleErrors,
};

export const handleCommonErrors = (error: unknown) => {
  if (error instanceof TransactionRevertInstructionError) {
    const decodedError = decodeErrorData(
      [...marketAMMAbi, ...marketAbi, ...marketFactoryAbi, ...centralizedOracleAbi],
      error,
    );

    if (decodedError.args && decodedError.name) {
      const message = ContractsErrors[decodedError.name](decodedError.args);
      throw message ? new Error(message) : error;
    } else {
      throw new Error(error.reason);
    }
  }
};

export default ContractsErrors;
