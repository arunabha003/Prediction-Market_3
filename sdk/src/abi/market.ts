const abi = [
  { type: 'constructor', inputs: [], stateMutability: 'nonpayable' },
  {
    type: 'function',
    name: 'addLiquidity',
    inputs: [
      { name: '_amount', type: 'uint256', internalType: 'uint256' },
      { name: '_deadline', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'buyShares',
    inputs: [
      { name: '_amount', type: 'uint256', internalType: 'uint256' },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_minOutcomeShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      { name: '_deadline', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'claimFees',
    inputs: [],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'claimLiquidity',
    inputs: [],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'claimRewards',
    inputs: [],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'closeMarket',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'creator',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'fees',
    inputs: [],
    outputs: [
      { name: 'feeBPS', type: 'uint256', internalType: 'uint256' },
      { name: 'poolWeight', type: 'uint256', internalType: 'uint256' },
      {
        name: 'totalFeesCollected',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getClaimableFees',
    inputs: [{ name: '_user', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'amount', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getFeeBPS',
    inputs: [],
    outputs: [{ name: 'feeBPS', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getInfo',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct IMarket.MarketInfo',
        components: [
          { name: 'question', type: 'string', internalType: 'string' },
          {
            name: 'outcomeCount',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'closeTime',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'createTime',
            type: 'uint256',
            internalType: 'uint256',
          },
          { name: 'closedAt', type: 'uint256', internalType: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getOutcomePrice',
    inputs: [
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [{ name: 'price', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getOutcomes',
    inputs: [],
    outputs: [
      { name: 'names', type: 'string[]', internalType: 'string[]' },
      {
        name: 'totalShares',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
      {
        name: 'poolShares',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPoolData',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct IMarket.MarketPoolData',
        components: [
          { name: 'balance', type: 'uint256', internalType: 'uint256' },
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'totalAvailableShares',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomes',
            type: 'tuple[]',
            internalType: 'struct IMarket.Outcome[]',
            components: [
              { name: 'name', type: 'string', internalType: 'string' },
              {
                name: 'shares',
                type: 'tuple',
                internalType: 'struct IMarket.Shares',
                components: [
                  {
                    name: 'total',
                    type: 'uint256',
                    internalType: 'uint256',
                  },
                  {
                    name: 'available',
                    type: 'uint256',
                    internalType: 'uint256',
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getResolveDelay',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getResolveOutcomeIndex',
    inputs: [],
    outputs: [{ name: 'outcomeIndex', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getUserClaimedFees',
    inputs: [{ name: '_user', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'claimedFees', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getUserLiquidityShares',
    inputs: [{ name: '_user', type: 'address', internalType: 'address' }],
    outputs: [{ name: 'shares', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getUserOutcomeShares',
    inputs: [
      { name: '_user', type: 'address', internalType: 'address' },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [{ name: 'shares', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'info',
    inputs: [],
    outputs: [
      { name: 'question', type: 'string', internalType: 'string' },
      {
        name: 'outcomeCount',
        type: 'uint256',
        internalType: 'uint256',
      },
      { name: 'closeTime', type: 'uint256', internalType: 'uint256' },
      { name: 'createTime', type: 'uint256', internalType: 'uint256' },
      { name: 'closedAt', type: 'uint256', internalType: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'initialize',
    inputs: [
      {
        name: '_marketInfo',
        type: 'tuple',
        internalType: 'struct IMarket.MarketInfoInput',
        components: [
          { name: 'question', type: 'string', internalType: 'string' },
          {
            name: 'outcomeNames',
            type: 'string[]',
            internalType: 'string[]',
          },
          {
            name: 'closeTime',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'resolveDelay',
            type: 'uint256',
            internalType: 'uint256',
          },
          { name: 'feeBPS', type: 'uint256', internalType: 'uint256' },
          { name: 'creator', type: 'address', internalType: 'address' },
        ],
      },
      {
        name: '_oracle',
        type: 'address',
        internalType: 'contract IOracle',
      },
      {
        name: '_marketAMM',
        type: 'address',
        internalType: 'contract IMarketAMM',
      },
      {
        name: '_initialLiquidity',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [],
    stateMutability: 'payable',
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
    name: 'oracle',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'contract IOracle' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'poolData',
    inputs: [],
    outputs: [
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
      { name: 'liquidity', type: 'uint256', internalType: 'uint256' },
      {
        name: 'totalAvailableShares',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'removeLiquidity',
    inputs: [
      { name: '_shares', type: 'uint256', internalType: 'uint256' },
      { name: '_deadline', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'resolveDelay',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'resolveMarket',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'sellShares',
    inputs: [
      {
        name: '_receiveAmount',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_maxOutcomeShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      { name: '_deadline', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'state',
    inputs: [],
    outputs: [
      {
        name: '',
        type: 'uint8',
        internalType: 'enum IMarket.MarketState',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'FeesClaimed',
    inputs: [
      {
        name: '_claimer',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
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
    name: 'LiquidityAdded',
    inputs: [
      {
        name: '_provider',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_liquidityShares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_liquidity',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'LiquidityClaimed',
    inputs: [
      {
        name: '_claimer',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'LiquidityRemoved',
    inputs: [
      {
        name: '_provider',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_shares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_liquidity',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketInitialized',
    inputs: [
      {
        name: '_question',
        type: 'string',
        indexed: false,
        internalType: 'string',
      },
      {
        name: '_outcomeCount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_closeTime',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_creator',
        type: 'address',
        indexed: false,
        internalType: 'address',
      },
      {
        name: '_oracle',
        type: 'address',
        indexed: false,
        internalType: 'address',
      },
      {
        name: '_marketAMM',
        type: 'address',
        indexed: false,
        internalType: 'address',
      },
      {
        name: '_initialLiquidity',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_resolveDelay',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_feeBPS',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'MarketStateUpdated',
    inputs: [
      {
        name: '_updatedAt',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_state',
        type: 'uint8',
        indexed: false,
        internalType: 'enum IMarket.MarketState',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'RewardsClaimed',
    inputs: [
      {
        name: '_claimer',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'SharesBought',
    inputs: [
      {
        name: '_buyer',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_fee',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_shares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'SharesSold',
    inputs: [
      {
        name: '_seller',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        indexed: true,
        internalType: 'uint256',
      },
      {
        name: '_amount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_fee',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: '_shares',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'error',
    name: 'AmountMismatch',
    inputs: [
      { name: 'expected', type: 'uint256', internalType: 'uint256' },
      { name: 'actual', type: 'uint256', internalType: 'uint256' },
    ],
  },
  { type: 'error', name: 'DeadlinePassed', inputs: [] },
  { type: 'error', name: 'InsufficientShares', inputs: [] },
  { type: 'error', name: 'InvalidCloseTime', inputs: [] },
  { type: 'error', name: 'InvalidFeeBPS', inputs: [] },
  { type: 'error', name: 'InvalidInitialization', inputs: [] },
  { type: 'error', name: 'InvalidMarketState', inputs: [] },
  {
    type: 'error',
    name: 'InvalidResolveDelay',
    inputs: [
      {
        name: 'MIN_RESOLVE_DELAY',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'MAX_RESOLVE_DELAY',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
  },
  { type: 'error', name: 'MarketCloseTimeNotPassed', inputs: [] },
  { type: 'error', name: 'MarketClosed', inputs: [] },
  { type: 'error', name: 'MarketResolveDelayNotPassed', inputs: [] },
  { type: 'error', name: 'MaxSharesNotMet', inputs: [] },
  { type: 'error', name: 'MinimumSharesNotMet', inputs: [] },
  { type: 'error', name: 'NoLiquidityToClaim', inputs: [] },
  { type: 'error', name: 'NoRewardsToClaim', inputs: [] },
  { type: 'error', name: 'NotInitializing', inputs: [] },
  { type: 'error', name: 'OnlyBinaryMarketSupported', inputs: [] },
  { type: 'error', name: 'OracleNotResolved', inputs: [] },
  { type: 'error', name: 'TransferFailed', inputs: [] },
  { type: 'error', name: 'ZeroAddress', inputs: [] },
] as const;

export default abi;
