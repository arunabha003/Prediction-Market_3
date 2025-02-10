const abi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  {
    type: 'function',
    name: 'UPGRADE_INTERFACE_VERSION',
    inputs: [],
    outputs: [{ name: '', type: 'string', internalType: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'createMarket',
    inputs: [
      { name: '_question', type: 'string', internalType: 'string' },
      {
        name: '_outcomeNames',
        type: 'string[]',
        internalType: 'string[]',
      },
      { name: '_closeTime', type: 'uint256', internalType: 'uint256' },
      {
        name: '_oracle',
        type: 'address',
        internalType: 'contract IOracle',
      },
      {
        name: '_initialLiquidity',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_resolveDelay',
        type: 'uint256',
        internalType: 'uint256',
      },
      { name: '_feeBPS', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'defaultOracleImplementation',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMarket',
    inputs: [{ name: 'index', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMarketCount',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'initialize',
    inputs: [
      { name: '_owner', type: 'address', internalType: 'address' },
      {
        name: '_marketImplementation',
        type: 'address',
        internalType: 'address',
      },
      {
        name: '_marketAMMImplementation',
        type: 'address',
        internalType: 'address',
      },
      {
        name: '_oracleImplementation',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'marketAMM',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'contract IMarketAMM' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'marketAMMImplementation',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'marketImplementation',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'markets',
    inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'proxiableUUID',
    inputs: [],
    outputs: [{ name: '', type: 'bytes32', internalType: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'renounceOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMarketAMMImplementation',
    inputs: [
      {
        name: '_marketAMMImplementation',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMarketImplementation',
    inputs: [
      {
        name: '_marketImplementation',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setOracleImplementation',
    inputs: [
      {
        name: '_oracleImplementation',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'transferOwnership',
    inputs: [{ name: 'newOwner', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'upgradeToAndCall',
    inputs: [
      {
        name: 'newImplementation',
        type: 'address',
        internalType: 'address',
      },
      { name: 'data', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'event',
    name: 'DefaultOracleImplementationSet',
    inputs: [
      {
        name: 'oracleImplementation',
        type: 'address',
        indexed: true,
        internalType: 'contract IOracle',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'Initialized',
    inputs: [
      {
        name: 'version',
        type: 'uint64',
        indexed: false,
        internalType: 'uint64',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketAMMImplementationSet',
    inputs: [
      {
        name: 'marketAMMImplementation',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketCreated',
    inputs: [
      {
        name: 'marketAddress',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'creator',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'marketIndex',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketFactoryInitialized',
    inputs: [],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketImplementationSet',
    inputs: [
      {
        name: 'marketImplementation',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'OwnershipTransferred',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'Upgraded',
    inputs: [
      {
        name: 'implementation',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'AddressEmptyCode',
    inputs: [{ name: 'target', type: 'address', internalType: 'address' }],
  },
  {
    type: 'error',
    name: 'ERC1967InvalidImplementation',
    inputs: [
      {
        name: 'implementation',
        type: 'address',
        internalType: 'address',
      },
    ],
  },
  { type: 'error', name: 'ERC1967NonPayable', inputs: [] },
  { type: 'error', name: 'FailedCall', inputs: [] },
  { type: 'error', name: 'FailedDeployment', inputs: [] },
  { type: 'error', name: 'IndexOutOfBounds', inputs: [] },
  {
    type: 'error',
    name: 'AmountMismatch',
    inputs: [
      { name: 'expected', type: 'uint256', internalType: 'uint256' },
      { name: 'actual', type: 'uint256', internalType: 'uint256' },
    ],
  },
  {
    type: 'error',
    name: 'InsufficientBalance',
    inputs: [
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
      { name: 'needed', type: 'uint256', internalType: 'uint256' },
    ],
  },
  { type: 'error', name: 'InvalidInitialization', inputs: [] },
  { type: 'error', name: 'NotInitializing', inputs: [] },
  {
    type: 'error',
    name: 'OwnableInvalidOwner',
    inputs: [{ name: 'owner', type: 'address', internalType: 'address' }],
  },
  {
    type: 'error',
    name: 'OwnableUnauthorizedAccount',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
  },
  { type: 'error', name: 'UUPSUnauthorizedCallContext', inputs: [] },
  {
    type: 'error',
    name: 'UUPSUnsupportedProxiableUUID',
    inputs: [{ name: 'slot', type: 'bytes32', internalType: 'bytes32' }],
  },
  { type: 'error', name: 'ZeroAddress', inputs: [] },
] as const;

export default abi;
