const abi = [
  {
    type: 'function',
    name: 'getAddLiquidityData',
    inputs: [
      { name: '_amount', type: 'uint256', internalType: 'uint256' },
      {
        name: '_marketParams',
        type: 'tuple',
        internalType: 'struct IMarketAMM.MarketPoolState',
        components: [
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomeShares',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [
      {
        name: 'liquidityShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'outcomeShareToReturn',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
      {
        name: 'newOutcomeShares',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
    ],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'getBuyOutcomeData',
    inputs: [
      { name: '_amount', type: 'uint256', internalType: 'uint256' },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_marketParams',
        type: 'tuple',
        internalType: 'struct IMarketAMM.MarketPoolState',
        components: [
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomeShares',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [{ name: 'shares', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'getClaimLiquidityData',
    inputs: [
      {
        name: '_liquidityShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_resolvedOutcomeShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      { name: '_liquidity', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: 'amount', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'pure',
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
      {
        name: '_totalAvailableShares',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_marketParams',
        type: 'tuple',
        internalType: 'struct IMarketAMM.MarketPoolState',
        components: [
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomeShares',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [{ name: 'price', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'getRemoveLiquidityData',
    inputs: [
      { name: '_shares', type: 'uint256', internalType: 'uint256' },
      {
        name: '_marketParams',
        type: 'tuple',
        internalType: 'struct IMarketAMM.MarketPoolState',
        components: [
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomeShares',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [
      {
        name: 'liquidityValue',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'outcomeSharesToReturn',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
      {
        name: 'newOutcomeShares',
        type: 'uint256[]',
        internalType: 'uint256[]',
      },
    ],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'getSellOutcomeData',
    inputs: [
      { name: '_amount', type: 'uint256', internalType: 'uint256' },
      {
        name: '_outcomeIndex',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: '_marketParams',
        type: 'tuple',
        internalType: 'struct IMarketAMM.MarketPoolState',
        components: [
          {
            name: 'liquidity',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'outcomeShares',
            type: 'uint256[]',
            internalType: 'uint256[]',
          },
        ],
      },
    ],
    outputs: [{ name: 'shares', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'pure',
  },
  { type: 'error', name: 'InsufficientLiquidity', inputs: [] },
] as const;

export default abi;
