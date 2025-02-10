import { registerDecorator, ValidationOptions } from 'class-validator';
import * as Web3Validator from 'web3-validator';

/**
 * Custom validation decorator to check if a string is a valid Ethereum address using web3-validator.
 * class-validator has built-in IsEthereumAddress decorator but using web3-validator is more reliable.
 */
export function IsEthereumAddress(validationOptions?: ValidationOptions) {
  return function (object: Object, propertyName: string) {
    registerDecorator({
      name: 'isEthereumAddress',
      target: object.constructor,
      propertyName: propertyName,
      constraints: [],
      options: {
        message: '$property must be a valid Ethereum address',
        ...validationOptions,
      },
      validator: {
        validate(value: any) {
          return (
            typeof value === 'string' && Web3Validator.isAddress(value, false)
          );
        },
      },
    });
  };
}
