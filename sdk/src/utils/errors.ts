import { utils, ContractAbi, TransactionRevertInstructionError, eth } from 'web3';
import { isAbiErrorFragment } from './abi';

export const decodeErrorData = (abi: ContractAbi, error: TransactionRevertInstructionError) => {
  const result: { name: string | null; args: { [K in string]: unknown } | null } = {
    name: null,
    args: null,
  };

  if (error.signature === undefined || error.data === undefined) {
    return result;
  }

  for (const fragment of abi) {
    if (isAbiErrorFragment(fragment)) {
      const inputs = fragment.inputs || [];
      const inputTypes = inputs.map(input => input.type);
      const fragmentSignature = utils.sha3(`${fragment.name}(${inputTypes.join(',')})`);

      if (fragmentSignature?.startsWith(error.signature)) {
        result.name = fragment.name;
        result.args = eth.abi.decodeParameters([...inputs], error.data);
        break;
      }
    }
  }

  return result;
};
