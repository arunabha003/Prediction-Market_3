// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Market.sol";
import "./MarketAMM.sol";

/**
 * @title PolymarketFactory
 * @notice Deploys new PolymarketMarket + PolymarketAMM pairs, all upgradeable if desired.
 */
contract PolymarketFactory is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // keep track of created markets
    address[] public allMarkets;
    address[] public allAMMs;

    event NewMarketCreated(
        address indexed market,
        address indexed amm,
        string question,
        uint256 closeTime
    );

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @dev required by UUPS
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Creates a new Market + AMM pair
     * @param usdc Address of USDC token
     * @param uri Base URI for the ERC1155 (e.g. ipfs or metadata endpoint)
     * @param question Market question
     * @param closeTime Market close time
     * @param oracle Oracle address
     * @param feeBps Fee for AMM trades (e.g. 100 => 1%)
     */
    function createMarket(
        address usdc,
        string memory uri,
        string memory question,
        uint256 closeTime,
        address oracle,
        uint256 feeBps
    ) external onlyOwner returns (address marketAddr, address ammAddr) {
        // 1) Deploy AMM
        PolymarketAMM amm = new PolymarketAMM();
        
        // address(0) is a placeholder for market; we'll fix after we deploy the market.

        // 2) Deploy Market
        PolymarketMarket market = new PolymarketMarket();
        market.initialize(
            usdc,
            uri,
            question,
            closeTime,
            oracle,
            address(amm)
        );

        amm.initialize(address(market), feeBps); 

        // 3) Now we have addresses, let's fix the reference in the AMM to the actual Market
        // We'll re-initialize or set a function on AMM for the correct address if needed
        // A simpler approach is to have a setMarket function:
        
        //amm.setMarket(address(market));

        // Transfer ownership of each contract to the factory owner if desired
        // or keep them separate. Here we do a safe approach:
        amm.transferOwnership(owner());
        market.transferOwnership(owner());

        // record
        marketAddr = address(market);
        ammAddr = address(amm);

        allMarkets.push(marketAddr);
        allAMMs.push(ammAddr);

        emit NewMarketCreated(marketAddr, ammAddr, question, closeTime);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    function getAllAMMs() external view returns (address[] memory) {
        return allAMMs;
    }
}
