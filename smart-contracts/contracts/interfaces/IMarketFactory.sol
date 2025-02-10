// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IOracle} from "./IOracle.sol";

/**
 * @title The interface for the prediction market factory contract
 * @notice The MarketFactory contract is used to create new prediction markets
 */
interface IMarketFactory {
    /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the MarketFactory is initialized
     */
    event MarketFactoryInitialized();

    /**
     * @notice Emitted when a new market is created
     * @param marketAddress The address of the newly created market
     * @param creator The address of the creator of the market
     * @param marketIndex The id of the newly created market
     */
    event MarketCreated(address indexed marketAddress, address indexed creator, uint256 indexed marketIndex);

    /**
     * @notice Emitted when the market implementation address is set
     * @param marketImplementation The address of the market implementation
     */
    event MarketImplementationSet(address indexed marketImplementation);

    /**
     * @notice Emitted when the market AMM implementation address is set
     * @param marketAMMImplementation The address of the market AMM implementation
     */
    event MarketAMMImplementationSet(address indexed marketAMMImplementation);

    /**
     * @notice Emitted when the default oracle implementation is set
     * @param oracleImplementation The address of the default oracle implementation
     */
    event DefaultOracleImplementationSet(IOracle indexed oracleImplementation);

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Creates a new market contract and adds its address to the markets array.
     * @param _question The question of the market
     * @param _outcomeNames The outcome names of the market
     * @param _closeTime  The close time of the market
     * @param _oracle The oracle address of the market
     * @param _initialLiquidity The initial liquidity of the market, added by the creator
     * @param _resolveDelay The delay in seconds before the oracle can resolve the market
     * @param _feeBPS The fee in basis points to be charged on the market
     */
    function createMarket(
        string calldata _question,
        string[] calldata _outcomeNames,
        uint256 _closeTime,
        IOracle _oracle,
        uint256 _initialLiquidity,
        uint256 _resolveDelay,
        uint256 _feeBPS
    ) external payable returns (address);

    /**
     * @notice Updates the market implementation address
     * @param _marketImplementation the address of the new market implementation
     */
    function setMarketImplementation(address _marketImplementation) external;

    /**
     * @notice Updates the market AMM implementation address
     * @param _marketAMMImplementation the address of the new MarketAMM implementation
     */
    function setMarketAMMImplementation(address _marketAMMImplementation) external;

    /**
     * @notice Updates the default Oracle implementation address
     * @param _oracleImplementation the address of the new Oracle implementation
     */
    function setOracleImplementation(address _oracleImplementation) external;

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Gets the total number of markets created
     * @return The total number of markets
     */
    function getMarketCount() external view returns (uint256);

    /**
     * @notice Gets the address of a market by index
     * @param index The index of the market
     * @return The address of the market
     */
    function getMarket(uint256 index) external view returns (address);
}
