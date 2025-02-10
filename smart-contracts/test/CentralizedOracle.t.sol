// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../contracts/errors/CommonErrors.sol";

import {IOracle} from "../contracts/interfaces/IOracle.sol";

import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

import {DeployCentralizedOracle} from "../script/DeployCentralizedOracle.s.sol";

contract CentralizedOracleTest is Test {
    event OutcomeSet(uint256 outcomeIndex);

    CentralizedOracle public oracle;

    address owner = makeAddr("owner");

    function setUp() public {
        DeployCentralizedOracle deployer = new DeployCentralizedOracle();

        oracle = deployer.run(owner);
    }

    /*//////////////////////////////////////////////////////////////
                              initialize
    //////////////////////////////////////////////////////////////*/
    function test_initialize_correct_owner() external view {
        assertEq(oracle.owner(), owner, "The owner is not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                              setOutcome
    //////////////////////////////////////////////////////////////*/
    function test_set_outcome_correctly_sets_outcome() external {
        // Arrange
        uint256 outcomeIndex = 1;

        vm.expectEmit();
        emit OutcomeSet(outcomeIndex);

        // Act
        vm.prank(owner);
        oracle.setOutcome(outcomeIndex);

        // Assert
        assertEq(oracle.getOutcome(), outcomeIndex, "The outcome index is not set correctly");
        assertEq(oracle.isResolved(), true, "The outcome is not resolved");
    }

    /*//////////////////////////////////////////////////////////////
                              getOutcome
    //////////////////////////////////////////////////////////////*/
    function test_get_outcome_returns_the_outcome_index() external {
        // Arrange
        uint256 outcomeIndex = 1;
        vm.prank(owner);
        oracle.setOutcome(outcomeIndex);

        // Act & Assert
        assertEq(oracle.getOutcome(), outcomeIndex, "The outcome index is not set correctly");
    }

    function test_get_outcome_reverts_when_not_resolved() external {
        // Act & Assert
        vm.expectRevert(IOracle.OutcomeNotResolvedYet.selector);
        oracle.getOutcome();
    }

    /*//////////////////////////////////////////////////////////////
                              isResolved
    //////////////////////////////////////////////////////////////*/
    function test_is_resolved_returns_false_when_not_resolved() external view {
        assertEq(oracle.isResolved(), false, "The outcome is resolved");
    }

    /*//////////////////////////////////////////////////////////////
                              _authorizeUpgrade
    //////////////////////////////////////////////////////////////*/
    function test__authorizeUpgrade() external {
        vm.expectRevert(ZeroAddress.selector);
        vm.prank(owner);
        oracle.upgradeToAndCall(address(0), bytes(""));
    }
}
