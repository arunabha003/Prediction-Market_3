// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IOracle} from "./interfaces/IOracle.sol";
import {IMarketFactory} from "./interfaces/IMarketFactory.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import {IMarketAMM} from "./interfaces/IMarketAMM.sol";

import "./errors/CommonErrors.sol";

import {Market} from "./Market.sol";
import {CentralizedOracle} from "./CentralizedOracle.sol";

/**
 * @title MarketFactory
 * @dev Minimal factory contract that stores market addresses in an array.
 */
contract MarketFactory is IMarketFactory, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    // Slot 0
    address[] public markets; // Array of market addresses

    // Slot 1
    address public marketImplementation; // Address of the Market implementation

    // Slot 2
    address public marketAMMImplementation; // Address of the MarketAMM implementation

    // Slot 3
    address public defaultOracleImplementation; // Address of the default Oracle implementation

    // Slot 4
    IMarketAMM public marketAMM; // MarketAMM contract

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Throws if the provided address is the zero address
     * @param _address the address to check
     */
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the MarketFactory contract
     * @param _owner the address of the owner
     * @param _marketImplementation the address of the Market implementation
     * @param _marketAMMImplementation the address of the MarketAMM implementation
     * @param _oracleImplementation the address of the default centralized Oracle implementation
     */
    function initialize(
        address _owner,
        address _marketImplementation,
        address _marketAMMImplementation,
        address _oracleImplementation
    )
        external
        initializer
        nonZeroAddress(_owner)
        nonZeroAddress(_marketImplementation)
        nonZeroAddress(_marketAMMImplementation)
        nonZeroAddress(_oracleImplementation)
    {
        __Ownable_init(_owner); // Initialize the Ownable contract
        __UUPSUpgradeable_init(); // Initialize the UUPSUpgradeable contract

        marketImplementation = _marketImplementation; // Set the Market implementation address
        marketAMMImplementation = _marketAMMImplementation; // Set the MarketAMM implementation address
        defaultOracleImplementation = _oracleImplementation; // Set the Default Oracle implementation address

        marketAMM = IMarketAMM(Clones.clone(marketAMMImplementation)); // Create a clone of the MarketAMM contract

        emit MarketFactoryInitialized();
    }

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
     */
    function createMarket(
        string calldata _question,
        string[] calldata _outcomeNames,
        uint256 _closeTime,
        IOracle _oracle,
        uint256 _initialLiquidity,
        uint256 _resolveDelay,
        uint256 _feeBPS
    ) external payable returns (address) {
        // Create a clone of the default Oracle implementation if no Oracle is provided
        if (address(_oracle) == address(0)) {
            CentralizedOracle defaultOracle = CentralizedOracle(Clones.clone(address(defaultOracleImplementation)));
            defaultOracle.initialize(msg.sender);
            _oracle = defaultOracle;
        }

        address clone = Clones.clone(marketImplementation); // Create a clone of the Market contract
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: _question,
            outcomeNames: _outcomeNames,
            closeTime: _closeTime,
            creator: msg.sender,
            resolveDelay: _resolveDelay,
            feeBPS: _feeBPS
        });
        Market(clone).initialize{value: msg.value}(marketInfo, _oracle, marketAMM, _initialLiquidity); // Initialize the new market

        markets.push(clone);
        emit MarketCreated(clone, msg.sender, markets.length - 1);

        return clone;
    }

    /**
     * @notice Updates the market implementation address
     * @param _marketImplementation the address of the new market implementation
     */
    function setMarketImplementation(address _marketImplementation)
        external
        onlyOwner
        nonZeroAddress(_marketImplementation)
    {
        marketImplementation = _marketImplementation;
        emit MarketImplementationSet(_marketImplementation);
    }

    /**
     * @notice Updates the market AMM implementation address
     * @param _marketAMMImplementation the address of the new MarketAMM implementation
     */
    function setMarketAMMImplementation(address _marketAMMImplementation)
        external
        onlyOwner
        nonZeroAddress(_marketAMMImplementation)
    {
        marketAMMImplementation = _marketAMMImplementation;
        marketAMM = IMarketAMM(Clones.clone(_marketAMMImplementation));
        emit MarketAMMImplementationSet(_marketAMMImplementation);
    }

    /**
     * @notice Updates the default Oracle implementation address
     * @param _oracleImplementation the address of the new Oracle implementation
     */
    function setOracleImplementation(address _oracleImplementation)
        external
        onlyOwner
        nonZeroAddress(_oracleImplementation)
    {
        defaultOracleImplementation = _oracleImplementation;
        emit DefaultOracleImplementationSet(CentralizedOracle(_oracleImplementation));
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Returns the number of stored markets.
     * @return The length of the markets array.
     */
    function getMarketCount() external view returns (uint256) {
        return markets.length;
    }

    /**
     * @dev Returns the market address at a specific index.
     * @param index index of the market to retrieve.
     * @return the address of the market at the specified index.
     */
    function getMarket(uint256 index) external view returns (address) {
        if (index >= markets.length) {
            revert IndexOutOfBounds();
        }
        return markets[index];
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Upgrades the Market Factory implementation.
     * @param newImplementation the address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
        nonZeroAddress(newImplementation)
    {}
}
