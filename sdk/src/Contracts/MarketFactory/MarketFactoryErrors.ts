export const AddressEmptyCodeError = (args: { [K in string]: unknown }) => {
  return `The address ${args[0]} has empty code.`;
};

export const ERC1967InvalidImplementationError = (args: { [K in string]: unknown }) => {
  return `The implementation address ${args[0]} is invalid.`;
};

export const ERC1967NonPayableError = () => {
  return `The function is non-payable.`;
};

export const FailedCallError = () => {
  return `The call has failed.`;
};

export const FailedDeploymentError = () => {
  return `The deployment has failed.`;
};

export const IndexOutOfBoundsError = () => {
  return `The index is out of bounds.`;
};

export const InsufficientBalanceError = (args: { [K in string]: unknown }) => {
  return `Insufficient balance. Balance: ${args[0]}, Needed: ${args[1]}.`;
};

export const InvalidInitializationError = () => {
  return `The initialization is invalid.`;
};

export const NotInitializingError = () => {
  return `The contract is not initializing.`;
};

export const OwnableInvalidOwnerError = (args: { [K in string]: unknown }) => {
  return `The owner address ${args[0]} is invalid.`;
};

export const OwnableUnauthorizedAccountError = (args: { [K in string]: unknown }) => {
  return `The account address ${args[0]} is unauthorized.`;
};

export const UUPSUnauthorizedCallContextError = () => {
  return `The call context is unauthorized for UUPS.`;
};

export const UUPSUnsupportedProxiableUUIDError = (args: { [K in string]: unknown }) => {
  return `The proxiable UUID slot ${args[0]} is unsupported.`;
};

export const ZeroAddressError = () => {
  return `The address is zero.`;
};

const errors: { [CustomError: string]: (args: { [K in string]: unknown }) => string } = {
  AddressEmptyCode: AddressEmptyCodeError,
  ERC1967InvalidImplementation: ERC1967InvalidImplementationError,
  ERC1967NonPayable: ERC1967NonPayableError,
  FailedCall: FailedCallError,
  FailedDeployment: FailedDeploymentError,
  IndexOutOfBounds: IndexOutOfBoundsError,
  InsufficientBalance: InsufficientBalanceError,
  InvalidInitialization: InvalidInitializationError,
  NotInitializing: NotInitializingError,
  OwnableInvalidOwner: OwnableInvalidOwnerError,
  OwnableUnauthorizedAccount: OwnableUnauthorizedAccountError,
  UUPSUnauthorizedCallContext: UUPSUnauthorizedCallContextError,
  UUPSUnsupportedProxiableUUID: UUPSUnsupportedProxiableUUIDError,
  ZeroAddress: ZeroAddressError,
};

export default errors;
