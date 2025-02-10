// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./errors/CommonErrors.sol";

import {IOracle} from "./interfaces/IOracle.sol";

/**
 * @dev A mock Oracle contract that returns a predefined outcome index.
 */
contract CentralizedOracle is IOracle, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    ///@notice Emitted when the outcome is set
    event OutcomeSet(uint256 outcomeIndex);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 private outcomeIndex; // The outcome index of the market.

    bool public isResolved; // A flag indicating whether the outcome has been resolved.

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
     * @dev Initializes the prediction market
     * @param owner Owner of the contract
     */
    function initialize(address owner) public initializer {
        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Sets the outcome index of the market.
     * @param _outcomeIndex The outcome index
     */
    function setOutcome(uint256 _outcomeIndex) external onlyOwner {
        outcomeIndex = _outcomeIndex;
        isResolved = true;
        emit OutcomeSet(_outcomeIndex);
    }

    /**
     * @dev Retrieves the outcome index of the market.
     * @return The outcome index
     */
    function getOutcome() external view override returns (uint256) {
        if (!isResolved) {
            revert OutcomeNotResolvedYet();
        }

        return outcomeIndex;
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
