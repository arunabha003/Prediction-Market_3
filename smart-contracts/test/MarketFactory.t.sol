// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {Market} from "../contracts/Market.sol";
import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

import "../contracts/errors/CommonErrors.sol";
import "../contracts/MarketFactory.sol";

import {DeployMarketFactory} from "../script/DeployMarketFactory.s.sol";

contract MarketFactoryTest is Test {
    MarketFactory factoryProxy;
    address market;
    address marketAMM;
    address oracle;

    address owner = makeAddr("owner");

    function setUp() public {
        // Deploy the Market contract
        DeployMarketFactory deployer = new DeployMarketFactory();

        factoryProxy = deployer.run(owner);

        market = address(deployer.marketImplementation());
        marketAMM = address(deployer.marketAMMImplementation());
        oracle = address(deployer.oracleImplementation());
    }

    /*//////////////////////////////////////////////////////////////
                              initialize
    //////////////////////////////////////////////////////////////*/
    function test_initialize() external view {
        assertEq(factoryProxy.owner(), owner);
        assertEq(factoryProxy.getMarketCount(), 0);
        assertEq(factoryProxy.marketImplementation(), market);
        assertEq(address(factoryProxy.marketAMMImplementation()), marketAMM);
        assertEq(address(factoryProxy.defaultOracleImplementation()), oracle);
    }

    /*//////////////////////////////////////////////////////////////
                              createMarket
    //////////////////////////////////////////////////////////////*/
    function test_createMarket_with_default_liquidity() external {
        // Arrange
        string memory question = "What is the meaning of life?";
        string[] memory outcomeNames = new string[](2);
        outcomeNames[0] = "42";
        outcomeNames[1] = "Not 42";
        uint256 closeTime = block.timestamp + 1 days;
        uint256 initialLiquidity = 100 ether;
        uint256 resolveDelay = 1 days;
        uint256 feeBPS = 100;

        // Act
        address newMarket = factoryProxy.createMarket{value: initialLiquidity}(
            question, outcomeNames, closeTime, IOracle(address(0)), initialLiquidity, resolveDelay, feeBPS
        );

        // Assert
        assertEq(factoryProxy.markets(0), newMarket);
        assertEq(factoryProxy.getMarketCount(), 1);
    }

    function test_createMarket_with_custom_oracle() external {
        // Arrange
        string memory question = "What is the meaning of life?";
        string[] memory outcomeNames = new string[](2);
        outcomeNames[0] = "42";
        outcomeNames[1] = "Not 42";
        uint256 closeTime = block.timestamp + 1 days;
        uint256 initialLiquidity = 100 ether;
        uint256 resolveDelay = 1 days;
        uint256 feeBPS = 100;

        // Act
        address newMarket = factoryProxy.createMarket{value: initialLiquidity}(
            question, outcomeNames, closeTime, IOracle(oracle), initialLiquidity, resolveDelay, feeBPS
        );

        // Assert
        assertEq(factoryProxy.markets(0), newMarket);
        assertEq(factoryProxy.getMarketCount(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                              setMarketImplementation
    //////////////////////////////////////////////////////////////*/
    function test_setMarketImplementation() external {
        // Arrange
        Market newMarket = new Market();

        // Act
        vm.prank(owner);
        factoryProxy.setMarketImplementation(address(newMarket));

        // Assert
        assertEq(factoryProxy.marketImplementation(), address(newMarket));
    }

    function test_setMarketImplementation_reverts_on_zero_address() external {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        factoryProxy.setMarketImplementation(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              setMarketAMMImplementation
    //////////////////////////////////////////////////////////////*/
    function test_setMarketAMMImplementation() external {
        // Arrange

        // Act
        vm.prank(owner);
        factoryProxy.setMarketAMMImplementation(address(0x13));

        // Assert
        assertEq(address(factoryProxy.marketAMMImplementation()), address(0x13));
    }

    function test_setMarketAMMImplementation_reverts_on_zero_address() external {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        factoryProxy.setMarketAMMImplementation(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              setOracleImplementation
    //////////////////////////////////////////////////////////////*/
    function test_setOracleImplementation() external {
        // Arrange
        CentralizedOracle newOracle = new CentralizedOracle();

        // Act
        vm.prank(owner);
        factoryProxy.setOracleImplementation(address(newOracle));

        // Assert
        assertEq(address(factoryProxy.defaultOracleImplementation()), address(newOracle));
    }

    function test_setOracleImplementation_reverts_on_zero_address() external {
        vm.prank(owner);
        vm.expectRevert(ZeroAddress.selector);
        factoryProxy.setOracleImplementation(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              getMarketCount
    //////////////////////////////////////////////////////////////*/
    function test_getMarketCount() external view {
        assertEq(factoryProxy.getMarketCount(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              getMarket
    //////////////////////////////////////////////////////////////*/
    function test_getMarket() external {
        // Arrange
        string memory question = "What is the meaning of life?";
        string[] memory outcomeNames = new string[](2);
        outcomeNames[0] = "42";
        outcomeNames[1] = "Not 42";
        uint256 closeTime = block.timestamp + 1 days;
        uint256 initialLiquidity = 100 ether;
        uint256 resolveDelay = 1 days;
        uint256 feeBPS = 100;

        // Act
        address newMarket = factoryProxy.createMarket{value: initialLiquidity}(
            question, outcomeNames, closeTime, IOracle(address(0)), initialLiquidity, resolveDelay, feeBPS
        );

        // Assert
        assertEq(factoryProxy.getMarketCount(), 1);
        assertEq(factoryProxy.getMarket(0), newMarket);
    }

    function test_getMarket_reverts_on_invalid_index() external {
        vm.expectRevert(IndexOutOfBounds.selector);
        factoryProxy.getMarket(1);
    }

    /*//////////////////////////////////////////////////////////////
                              _authorizeUpgrade
    //////////////////////////////////////////////////////////////*/
    function test__authorizeUpgrade() external {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(owner);
        factoryProxy.upgradeToAndCall(address(0), bytes(""));
    }
}
