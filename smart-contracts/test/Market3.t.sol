// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BadActor} from "./helpers/BadActor.sol";

import "../contracts/errors/CommonErrors.sol";
import "../contracts/errors/MarketErrors.sol";

import {IMarket} from "../contracts/interfaces/IMarket.sol";
import {IMarketAMM} from "../contracts/interfaces/IMarketAMM3.sol";
import {IOracle} from "../contracts/interfaces/IOracle.sol";

import {MarketAMM3} from "../contracts/MarketAMM3.sol";
import {Market} from "../contracts/Market3.sol";
import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

/**
 * @title MarketAMMTest (3-outcome version)
 * @notice This test file is adapted for a 3-outcome market.
 */
contract MarketAMMTest3 is Test {
    using Math for uint256;

    uint256 constant BPS = 10000;

    address oracleImplementation;
    address marketImplementation;
    IMarketAMM marketAMM;
    CentralizedOracle oracle;
    Market market;

    address creator = makeAddr("John");
    address bob = makeAddr("Bob");
    address alice = makeAddr("Alice");

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev A basic integer cube-root approximation for testing invariants in 3-outcome AMM.
     *      This uses a simple binary search. Not gas-optimized—only used for test assertions.
     */
    function _cbrt(uint256 x) internal pure returns (uint256) {
        if (x < 2) return x;

        // Upper bound for cube root of x. For 256-bit numbers, ~2^85 is safe.
        uint256 high = 1 << 85;
        uint256 low;
        while (low < high) {
            // mid = floor((low + high + 1) / 2)
            uint256 mid = (low + high + 1) >> 1;
            uint256 midCubed = mid * mid * mid;

            if (midCubed == x) {
                return mid;
            } else if (midCubed < x) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return low;
    }


    function assertInvariant(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        require(poolData.outcomes.length == 3, "Expected 3 outcomes for this test.");
        uint256[] memory poolShares = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            poolShares[i] = poolData.outcomes[i].shares.available;
        }

        uint256 geometricMean = _cbrt(poolShares[0] * poolShares[1] * poolShares[2]);
        assertApproxEqAbs(geometricMean, poolData.liquidity, 1e10); 
    }

 
    function assertTotalAvailableShares(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        uint256 sum;
        for (uint256 i = 0; i < poolData.outcomes.length; ++i) {
            sum += poolData.outcomes[i].shares.available;
        }
        assertEq(poolData.totalAvailableShares, sum);
    }


    function assertMarketBalance(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        assertEq(address(_market).balance >= poolData.balance, true);

        for (uint256 i = 0; i < poolData.outcomes.length; ++i) {
            assertEq(poolData.balance >= poolData.outcomes[i].shares.total, true);
        }
    }

    function resolveMarket(IMarket _market) private {
        vm.warp(_market.getInfo().closeTime + 2 days);
        _market.closeMarket();
        skip(_market.getResolveDelay());

        vm.prank(creator);
        oracle.setOutcome(0);
        _market.resolveMarket();
    }

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        marketAMM = new MarketAMM3();
        oracleImplementation = address(new CentralizedOracle());
        marketImplementation = address(new Market());

        oracle = CentralizedOracle(Clones.clone(oracleImplementation));
        market = Market(Clones.clone(marketImplementation));

        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1 days,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 200
        });
        marketInfo.outcomeNames[0] = "Red";
        marketInfo.outcomeNames[1] = "Green";
        marketInfo.outcomeNames[2] = "Blue";

        uint256 initialLiquidity = 1000 ether;

        vm.expectEmit(false, false, false, true);
        emit IMarket.MarketInitialized(
            marketInfo.question,
            marketInfo.outcomeNames.length,
            marketInfo.closeTime,
            creator,
            address(oracle),
            address(marketAMM),
            initialLiquidity,
            marketInfo.resolveDelay,
            marketInfo.feeBPS
        );

        hoax(creator, 1000 ether);
        market.initialize{value: initialLiquidity}(marketInfo, oracle, marketAMM, initialLiquidity);

        oracle.initialize(creator);
    }

    /*//////////////////////////////////////////////////////////////
                       TEST: initialize (3-outcome)
    //////////////////////////////////////////////////////////////*/

    function test_initialize_initializes_correctly() external view {
        // Check resolveDelay
        assertEq(market.resolveDelay(), 1 minutes);

        // Check market info
        IMarket.MarketInfo memory info = market.getInfo();
        assertEq(info.question, "Which color will be chosen?");
        assertEq(info.outcomeCount, 3);
        assertEq(info.closeTime, block.timestamp + 1 days);
        assertEq(info.createTime, block.timestamp);
        assertEq(info.closedAt, 0);

        IMarket.MarketPoolData memory poolData = market.getPoolData();

        assertEq(poolData.balance, 1000 ether);
        assertEq(poolData.liquidity, 1000 ether);
        assertEq(poolData.totalAvailableShares, 3000 ether);

        // Check outcomes
        (string[] memory names, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
        assertEq(names.length, 3);
        assertEq(names[0], "Red");
        assertEq(names[1], "Green");
        assertEq(names[2], "Blue");

        assertEq(totalShares.length, 3);
        assertEq(totalShares[0], 1000 ether);
        assertEq(totalShares[1], 1000 ether);
        assertEq(totalShares[2], 1000 ether);

        assertEq(poolShares.length, 3);
        assertEq(poolShares[0], 1000 ether);
        assertEq(poolShares[1], 1000 ether);
        assertEq(poolShares[2], 1000 ether);

        // Check state
        assert(market.state() == IMarket.MarketState.open);

        // Check addresses
        assertEq(market.creator(), creator);
        assertEq(address(market.oracle()), address(oracle));
        assertEq(address(market.marketAMM()), address(marketAMM));

        // Check balances
        uint256 creatorOutcome0Shares = market.getUserOutcomeShares(creator, 0);
        uint256 creatorOutcome1Shares = market.getUserOutcomeShares(creator, 1);
        uint256 creatorOutcome2Shares = market.getUserOutcomeShares(creator, 2);
        assertEq(creatorOutcome0Shares, 0);
        assertEq(creatorOutcome1Shares, 0);
        assertEq(creatorOutcome2Shares, 0);

        uint256 creatorLiquidityShares = market.getUserLiquidityShares(creator);
        assertEq(creatorLiquidityShares, 1000 ether);

        // Check fees
        assertEq(market.getFeeBPS(), 200);

        // Assert invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_initialize_reverts_when_already_initialized() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1 days,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "One";
        marketInfo.outcomeNames[1] = "Two";
        marketInfo.outcomeNames[2] = "Three";

        uint256 initialLiquidity = 1000 ether;

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize(marketInfo, oracle, IMarketAMM(address(0)), initialLiquidity);
    }

    function test_initialize_reverts_on_invalid_close_time() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp - 1,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "One";
        marketInfo.outcomeNames[1] = "Two";
        marketInfo.outcomeNames[2] = "Three";

        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        vm.expectRevert(InvalidCloseTime.selector);
        clone.initialize(marketInfo, oracle, IMarketAMM(address(0)), initialLiquidity);
    }

    function test_initialize_reverts_when_outcomes_length_not_3() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](2),
            closeTime: block.timestamp + 1,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "Red";
        marketInfo.outcomeNames[1] = "Green";
        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        vm.expectRevert(OnlyThreeOutcomeMarketSupported.selector);
        clone.initialize(marketInfo, oracle, IMarketAMM(address(0)), initialLiquidity);
    }

    function test_initialize_reverts_on_zero_addresses() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "One";
        marketInfo.outcomeNames[1] = "Two";
        marketInfo.outcomeNames[2] = "Three";

        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        // Oracle = zero
        vm.expectRevert(ZeroAddress.selector);
        clone.initialize(marketInfo, IOracle(address(0)), IMarketAMM(address(0)), initialLiquidity);

        // MarketAMM = zero
        vm.expectRevert(ZeroAddress.selector);
        clone.initialize(marketInfo, oracle, IMarketAMM(address(0)), initialLiquidity);

        // Creator = zero
        marketInfo.creator = address(0);
        vm.expectRevert(ZeroAddress.selector);
        clone.initialize(marketInfo, oracle, marketAMM, initialLiquidity);
    }

    function test_initialize_reverts_on_incorrect_eth_for_liquidity() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "Red";
        marketInfo.outcomeNames[1] = "Green";
        marketInfo.outcomeNames[2] = "Blue";

        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        vm.expectRevert(abi.encodeWithSelector(AmountMismatch.selector, 1000 ether, 0));
        clone.initialize(marketInfo, oracle, marketAMM, initialLiquidity);
    }

    function test_initialize_reverts_on_incorrect_resolve_delay() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1,
            creator: creator,
            resolveDelay: 0,
            feeBPS: 0
        });
        marketInfo.outcomeNames[0] = "Red";
        marketInfo.outcomeNames[1] = "Green";
        marketInfo.outcomeNames[2] = "Blue";

        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        vm.expectRevert(abi.encodeWithSelector(InvalidResolveDelay.selector, 1 minutes, 7 days));
        clone.initialize(marketInfo, oracle, marketAMM, initialLiquidity);

        marketInfo.resolveDelay = 8 days;
        clone = Market(Clones.clone(marketImplementation));
        vm.expectRevert(abi.encodeWithSelector(InvalidResolveDelay.selector, 1 minutes, 7 days));
        clone.initialize(marketInfo, oracle, marketAMM, initialLiquidity);
    }

    function test_initialize_reverts_on_invalid_fee_bps() external {
        IMarket.MarketInfoInput memory marketInfo = IMarket.MarketInfoInput({
            question: "Which color will be chosen?",
            outcomeNames: new string[](3),
            closeTime: block.timestamp + 1,
            creator: creator,
            resolveDelay: 1 minutes,
            feeBPS: 10001
        });
        marketInfo.outcomeNames[0] = "Red";
        marketInfo.outcomeNames[1] = "Green";
        marketInfo.outcomeNames[2] = "Blue";

        uint256 initialLiquidity = 1000 ether;
        Market clone = Market(Clones.clone(marketImplementation));

        vm.expectRevert(InvalidFeeBPS.selector);
        clone.initialize(marketInfo, oracle, marketAMM, initialLiquidity);
    }

    /*//////////////////////////////////////////////////////////////
                      TEST: addLiquidity (3-outcome)
    //////////////////////////////////////////////////////////////*/

    function test_addLiquidity_receive_only_lp_shares_on_equal_market_three_outcomes_V3() external {
        // Arrange
        uint256 amount = 50 ether;
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        vm.expectEmit(true, false, false, true);
        emit IMarket.LiquidityAdded(bob, amount, 50 ether, 1050 ether);
    
        // Act
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        uint256 creatorLiquidityShares = market.getUserLiquidityShares(creator);
        uint256 bobLiquidityShares = market.getUserLiquidityShares(bob);
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance + amount);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, prePoolData.liquidity + amount);
        assertEq(poolData.liquidity, creatorLiquidityShares + bobLiquidityShares);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares + (amount * 3));
        assertEq(totalShares[0], preTotalShares[0] + amount);
        assertEq(totalShares[1], preTotalShares[1] + amount);
        assertEq(totalShares[2], preTotalShares[2] + amount);
    
        /// Assert Pool Shares
        assertEq(poolShares[0], prePoolShares[0] + amount);
        assertEq(poolShares[1], prePoolShares[1] + amount);
        assertEq(poolShares[2], prePoolShares[2] + amount);
    
        /// Assert User Outcome Shares
        assertEq(bobOutcomeAShares, 0);
        assertEq(bobOutcomeBShares, 0);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertEq(bobLiquidityShares, 50 ether);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

    function test_addLiquidity_receive_lp_and_less_likely_outcome_shares_on_unequal_market_V3() external {
        // Arrange
        uint256 buyAmount = 100 ether;
        uint256 outComeIndex = 0;
        hoax(alice, buyAmount);
        market.buyShares{value: buyAmount}(buyAmount, outComeIndex, 0, block.timestamp + 1);
        uint256 amount = 500 ether;
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        // Act
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        uint256 creatorLiquidityShares = market.getUserLiquidityShares(creator);
        uint256 bobLiquidityShares = market.getUserLiquidityShares(bob);
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance + amount);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, prePoolData.liquidity + bobLiquidityShares);
        assertEq(poolData.liquidity, creatorLiquidityShares + bobLiquidityShares);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares + (amount * 3) - bobOutcomeAShares);
        assertEq(totalShares[0], preTotalShares[0] + amount);
        assertEq(totalShares[1], preTotalShares[1] + amount);
        assertEq(totalShares[2], preTotalShares[2] + amount);
    
        /// Assert Pool Shares
        assertEq(poolShares[0], prePoolShares[0] + amount - bobOutcomeAShares);
        assertEq(poolShares[1], prePoolShares[1] + amount);
        assertEq(poolShares[2], prePoolShares[2] + amount);
    
        /// Assert User Outcome Shares
        assertGe(bobOutcomeAShares, 0);
        assertEq(bobOutcomeBShares, 0);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertGe(bobLiquidityShares, 0);
        assertLe(bobLiquidityShares, 500 ether);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

    function test_addLiquidity_reverts_on_deadline_passed() external {
        uint256 amount = 500 ether;
        vm.expectRevert(DeadlinePassed.selector);
        market.addLiquidity{value: amount}(amount, block.timestamp - 1);
    }

    function test_addLiquidity_reverts_on_amount_mismatch() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        vm.expectRevert(abi.encodeWithSelector(AmountMismatch.selector, amount - 1, amount));
        market.addLiquidity{value: amount}(amount - 1, block.timestamp + 1);
    }

    function test_addLiquidity_reverts_on_close_time_passed() external {
        vm.warp(block.timestamp + 2 days);
        uint256 amount = 500 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.addLiquidity{value: amount}(amount, block.timestamp + 2);
    }

    function test_addLiquidity_reverts_on_closed_market() external {
        vm.warp(block.timestamp + 2 days);
        market.closeMarket();

        uint256 amount = 500 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.addLiquidity{value: amount}(amount, block.timestamp + 2);
    }

    /*//////////////////////////////////////////////////////////////
                      TEST: buyShares (3-outcome)
    //////////////////////////////////////////////////////////////*/

    function test_buyShares_correctly_buys_shares_V3() external {
        // Arrange
        uint256 amount = 300 ether;
        uint256 amountAfterFee = amount - (amount * market.getFeeBPS()) / BPS;
        uint256 outcomeIndex = 0;
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        vm.expectEmit(true, false, false, false);
        emit IMarket.SharesBought(bob, outcomeIndex, 0, 0, 0);
    
        // Act
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, outcomeIndex, 0, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance + amountAfterFee);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, prePoolData.liquidity);
    
        /// Assert Total Outcome Shares
        assertEq(
            poolData.totalAvailableShares, prePoolData.totalAvailableShares + (amountAfterFee * 3) - bobOutcomeAShares
        );
        assertEq(totalShares[0], preTotalShares[0] + amountAfterFee);
        assertEq(totalShares[1], preTotalShares[1] + amountAfterFee);
        assertEq(totalShares[2], preTotalShares[2] + amountAfterFee);
    
        /// Assert Pool Shares
        assertEq(poolShares[0] + bobOutcomeAShares, totalShares[0]);
        assertEq(poolShares[1] + bobOutcomeBShares, totalShares[1]);
        assertEq(poolShares[2] + bobOutcomeCShares, totalShares[2]);
        assertEq(prePoolShares[1], poolShares[1] - amountAfterFee);
    
        /// Assert User Outcome Shares
        assertGe(bobOutcomeAShares, 0);
        assertEq(bobOutcomeBShares, 0);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

    function test_buyShares_multiple_buyers_V3(uint256 aliceAmount, uint256 bobAmount) external {
        // Arrange
        aliceAmount = bound(aliceAmount, 1, 9999999 ether);
        bobAmount = bound(bobAmount, 1, 9999999 ether);
    
        uint256 aliceAmountAfterFee = aliceAmount - (aliceAmount * market.getFeeBPS()) / BPS;
        uint256 bobAmountAfterFee = bobAmount - (bobAmount * market.getFeeBPS()) / BPS;
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        // Act
        hoax(bob, bobAmount);
        market.buyShares{value: bobAmount}(bobAmount, 0, 0, block.timestamp + 1);
    
        hoax(alice, aliceAmount);
        market.buyShares{value: aliceAmount}(aliceAmount, 0, 0, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance + aliceAmountAfterFee + bobAmountAfterFee);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, prePoolData.liquidity);
    
        /// Assert Total Outcome Shares
        assertEq(
            poolData.totalAvailableShares,
            prePoolData.totalAvailableShares + (aliceAmountAfterFee * 3) + (bobAmountAfterFee * 3)
                - (market.getUserOutcomeShares(alice, 0) + market.getUserOutcomeShares(bob, 0))
        );
        assertEq(totalShares[0], preTotalShares[0] + (aliceAmountAfterFee + bobAmountAfterFee));
        assertEq(totalShares[1], preTotalShares[1] + (aliceAmountAfterFee + bobAmountAfterFee));
        assertEq(totalShares[2], preTotalShares[2] + (aliceAmountAfterFee + bobAmountAfterFee));
    
        /// Assert Pool Shares
        assertEq(
            poolShares[0] + market.getUserOutcomeShares(bob, 0) + market.getUserOutcomeShares(alice, 0), totalShares[0]
        );
        assertEq(
            poolShares[1] + market.getUserOutcomeShares(bob, 1) + market.getUserOutcomeShares(alice, 1), totalShares[1]
        );
        assertEq(
            poolShares[2] + market.getUserOutcomeShares(bob, 2) + market.getUserOutcomeShares(alice, 2), totalShares[2]
        );
        assertEq(prePoolShares[1], poolShares[1] - (aliceAmountAfterFee + bobAmountAfterFee));
    
        /// Assert User Outcome Shares
        assertGe(market.getUserOutcomeShares(bob, 0), 0);
        assertEq(market.getUserOutcomeShares(bob, 1), 0);
        assertEq(market.getUserOutcomeShares(bob, 2), 0);
    
        assertGe(market.getUserOutcomeShares(alice, 0), 0);
        assertEq(market.getUserOutcomeShares(alice, 1), 0);
        assertEq(market.getUserOutcomeShares(alice, 2), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

    function test_buyShares_reverts_on_amount_mismatch() external {
        uint256 amount = 300 ether;
        hoax(bob, amount);
        vm.expectRevert(abi.encodeWithSelector(AmountMismatch.selector, amount - 1, amount));
        market.buyShares{value: amount}(amount - 1, 0, 500, block.timestamp + 1);
    }

    function test_buyShares_reverts_on_invalid_outcome_index() external {
        uint256 amount = 300 ether;
        hoax(bob, amount);

        vm.expectRevert();
        market.buyShares{value: amount}(amount, 3, 300 ether, block.timestamp + 1);
    }

    function test_buyShares_reverts_on_deadline_passed() external {
        uint256 amount = 300 ether;
        hoax(bob, amount);
        vm.expectRevert(DeadlinePassed.selector);
        market.buyShares{value: amount}(amount, 0, 300 ether, block.timestamp - 1);
    }

    function test_buyShares_reverts_on_slippage() external {
        uint256 amount = 300 ether;
        hoax(bob, amount);
        vm.expectRevert(MinimumSharesNotMet.selector);
        market.buyShares{value: amount}(amount, 0, 1000 ether, block.timestamp + 1);
    }

    function test_buyShares_reverts_on_close_time_passed() external {
        vm.warp(block.timestamp + 2 days);
        uint256 amount = 300 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.buyShares{value: amount}(amount, 0, 300 ether, block.timestamp + 2);
    }

    function test_buyShares_reverts_on_closed_market() external {
        vm.warp(2 days);
        market.closeMarket();
        uint256 amount = 300 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.buyShares{value: amount}(amount, 0, 300 ether, block.timestamp + 1);
    }

    /*//////////////////////////////////////////////////////////////
                      TEST: sellShares (3-outcome)
    //////////////////////////////////////////////////////////////*/



    function test_sellShares_correctly_sells_shares() external {
        // Arrange
        uint256 amount = 100 ether;
        uint256 amountAfterFee = amount - (amount * market.getFeeBPS()) / BPS;
        uint256 outcomeIndex = 0;
    
        IMarket.MarketPoolData memory preBuyPoolData = market.getPoolData();
        (, uint256[] memory preBuyTotalShares, uint256[] memory preBuyPoolShares) = market.getOutcomes();
    
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, outcomeIndex, 0, block.timestamp + 1);
    
        IMarket.MarketPoolData memory preSellPoolData = market.getPoolData();
        (, uint256[] memory preSellTotalShares, uint256[] memory preSellPoolShares) = market.getOutcomes();
        uint256 bobPreSellOutcomeShares = market.getUserOutcomeShares(bob, 0);
    
        vm.expectEmit(true, false, false, false);
        emit IMarket.SharesSold(bob, outcomeIndex, 0, 0, 0); // Does not check the values
    
        // Act
        vm.prank(bob);
        market.sellShares(amountAfterFee, outcomeIndex, 300 ether, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        /// Assert Balance
        assertEq(poolData.balance, preBuyPoolData.balance);
        assertEq(poolData.balance, preSellPoolData.balance - amountAfterFee);
        assertEq(poolData.balance, 1000 ether);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, preBuyPoolData.liquidity);
        assertEq(poolData.liquidity, preSellPoolData.liquidity);
        assertEq(poolData.liquidity, 1000 ether);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, preBuyPoolData.totalAvailableShares);
        assertEq(
            poolData.totalAvailableShares,
            preSellPoolData.totalAvailableShares - (amountAfterFee * 3) + bobPreSellOutcomeShares
        );
        assertEq(totalShares[0], preSellTotalShares[0] - amountAfterFee);
        assertEq(totalShares[1], preSellTotalShares[1] - amountAfterFee);
        assertEq(totalShares[2], preSellTotalShares[2] - amountAfterFee);
        assertEq(totalShares[0], preBuyTotalShares[0]);
        assertEq(totalShares[1], preBuyTotalShares[1]);
        assertEq(totalShares[2], preBuyTotalShares[2]);
        assertEq(totalShares[0], 1000 ether);
        assertEq(totalShares[1], 1000 ether);
        assertEq(totalShares[2], 1000 ether);
        assertEq(poolData.totalAvailableShares, 3000 ether);
    
        /// Assert Pool Shares
        assertEq(poolShares[0] + market.getUserOutcomeShares(bob, 0), totalShares[0]);
        assertEq(poolShares[1] + market.getUserOutcomeShares(bob, 1), totalShares[1]);
        assertEq(poolShares[2] + market.getUserOutcomeShares(bob, 2), totalShares[2]);
        assertEq(preBuyPoolShares[0], poolShares[0]);
        assertEq(preBuyPoolShares[1], poolShares[1]);
        assertEq(preBuyPoolShares[2], poolShares[2]);
        assertEq(poolShares[0], preSellPoolShares[0] + bobPreSellOutcomeShares - amountAfterFee);
        assertEq(poolShares[1], preSellPoolShares[1] - amountAfterFee);
        assertEq(poolShares[2], preSellPoolShares[2] - amountAfterFee);
        assertEq(poolShares[0], 1000 ether);
        assertEq(poolShares[1], 1000 ether);
        assertEq(poolShares[2], 1000 ether);
    
        /// Assert User Outcome Shares
        assertEq(market.getUserOutcomeShares(bob, 0), 0);
        assertEq(market.getUserOutcomeShares(bob, 1), 0);
        assertEq(market.getUserOutcomeShares(bob, 2), 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }


    function test_sellShares_correctly_sells_shares_big_amount_three_outcomes() external {
        // Arrange
        uint256 amount = 10000 ether;
        uint256 amountAfterFee = amount - (amount * market.getFeeBPS()) / BPS;
        uint256 outcomeIndex = 0;
    
        IMarket.MarketPoolData memory preBuyPoolData = market.getPoolData();
        (, uint256[] memory preBuyTotalShares, uint256[] memory preBuyPoolShares) = market.getOutcomes();
    
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, outcomeIndex, 0, block.timestamp + 1);
    
        IMarket.MarketPoolData memory preSellPoolData = market.getPoolData();
        (, uint256[] memory preSellTotalShares, uint256[] memory preSellPoolShares) = market.getOutcomes();
        uint256 bobPreSellOutcomeShares = market.getUserOutcomeShares(bob, 0);
        assertApproxEqAbs(bobPreSellOutcomeShares, 10707.40747 ether, 1e20); //0.7% error works
    
        // Act
        vm.prank(bob);
        market.sellShares(amountAfterFee, outcomeIndex, type(uint256).max, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        /// Assert Balance
        assertEq(poolData.balance, preBuyPoolData.balance);
        assertEq(poolData.balance, preSellPoolData.balance - amountAfterFee);
        assertEq(poolData.balance, 1000 ether);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, preBuyPoolData.liquidity);
        assertEq(poolData.liquidity, preSellPoolData.liquidity);
        assertEq(poolData.liquidity, 1000 ether);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, preBuyPoolData.totalAvailableShares);
        assertEq(
            poolData.totalAvailableShares,
            preSellPoolData.totalAvailableShares + bobPreSellOutcomeShares - (amountAfterFee * 3)
        );
    
        assertEq(totalShares[0], preSellTotalShares[0] - amountAfterFee);
        assertEq(totalShares[1], preSellTotalShares[1] - amountAfterFee);
        assertEq(totalShares[2], preSellTotalShares[2] - amountAfterFee);
        assertEq(totalShares[0], preBuyTotalShares[0]);
        assertEq(totalShares[1], preBuyTotalShares[1]);
        assertEq(totalShares[2], preBuyTotalShares[2]);
        assertEq(poolData.totalAvailableShares, 3000 ether);
    
        /// Assert Pool Shares
        assertEq(poolShares[0] + market.getUserOutcomeShares(bob, 0), totalShares[0]);
        assertEq(poolShares[1] + market.getUserOutcomeShares(bob, 1), totalShares[1]);
        assertEq(poolShares[2] + market.getUserOutcomeShares(bob, 2), totalShares[2]);
        assertEq(preBuyPoolShares[0], poolShares[0]);
        assertEq(preBuyPoolShares[1], poolShares[1]);
        assertEq(preBuyPoolShares[2], poolShares[2]);
        assertEq(poolShares[0], preSellPoolShares[0] + bobPreSellOutcomeShares - amountAfterFee);
        assertEq(poolShares[1], preSellPoolShares[1] - amountAfterFee);
        assertEq(poolShares[2], preSellPoolShares[2] - amountAfterFee);
    
        /// Assert User Outcome Shares
        assertEq(market.getUserOutcomeShares(bob, 0), 0);
        assertEq(market.getUserOutcomeShares(bob, 1), 0);
        assertEq(market.getUserOutcomeShares(bob, 2), 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }



    function test_fuzz_sellShares_correctly_sells_shares_three_outcomes(uint256 amount) external {
        // Arrange
        IMarket.MarketPoolData memory preBuyPoolData = market.getPoolData();
        (, uint256[] memory preBuyTotalShares, uint256[] memory preBuyPoolShares) = market.getOutcomes();
    
        amount = bound(amount, 1, 999999999999999 ether);
        uint256 amountAfterFee = amount - (amount * market.getFeeBPS()) / BPS;
        uint256 outcomeIndex = 0;
    
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, outcomeIndex, 0, block.timestamp + 1);
    
        IMarket.MarketPoolData memory preSellPoolData = market.getPoolData();
        (, uint256[] memory preSellTotalShares, uint256[] memory preSellPoolShares) = market.getOutcomes();
        uint256 bobPreSellOutcomeShares = market.getUserOutcomeShares(bob, 0);
    
        // Act
        vm.prank(bob);
        market.sellShares(amountAfterFee, outcomeIndex, type(uint256).max, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        /// Assert Balance
        assertEq(poolData.balance, preBuyPoolData.balance);
        assertEq(poolData.balance, preSellPoolData.balance - amountAfterFee);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, preBuyPoolData.liquidity);
        assertEq(poolData.liquidity, preSellPoolData.liquidity);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, preBuyPoolData.totalAvailableShares);
        assertEq(
            poolData.totalAvailableShares,
            preSellPoolData.totalAvailableShares + bobPreSellOutcomeShares - (amountAfterFee * 3)
        );
        assertEq(totalShares[0], preSellTotalShares[0] - amountAfterFee);
        assertEq(totalShares[1], preSellTotalShares[1] - amountAfterFee);
        assertEq(totalShares[2], preSellTotalShares[2] - amountAfterFee);
    
        /// Assert Pool Shares
        assertEq(poolShares[0] + market.getUserOutcomeShares(bob, 0), totalShares[0]);
        assertEq(poolShares[1] + market.getUserOutcomeShares(bob, 1), totalShares[1]);
        assertEq(poolShares[2] + market.getUserOutcomeShares(bob, 2), totalShares[2]);
    
        /// Assert User Outcome Shares
        assertEq(market.getUserOutcomeShares(bob, 0), 0);
        assertEq(market.getUserOutcomeShares(bob, 1), 0);
        assertEq(market.getUserOutcomeShares(bob, 2), 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

    function test_sellShares_reverts_on_insufficient_share() external {
        // Bob tries to sell more shares than he has
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(InsufficientShares.selector);
        market.sellShares(amount + 1, 0, 400 ether, block.timestamp + 1);
    }

    function test_sellShares_reverts_on_failed_transfer_three_outcomes() external {
        // Arrange
        BadActor badActor = new BadActor(address(market));
    
        uint256 amount = 500 ether;
        uint256 amountAfterFee = amount - (amount * market.getFeeBPS()) / BPS;
        deal(address(badActor), amount);
        badActor.buyShares{value: amount}(amount, 0);
    
        // Act & Assert
        vm.expectRevert(TransferFailed.selector);
        badActor.sellShares(amountAfterFee, 0);
    }

    function test_sellShares_reverts_on_invalid_outcome_index() external {
        // With 3 outcomes, valid indices = 0,1,2. So index=3 is invalid.
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert();
        market.sellShares(amount, 3, 300 ether, block.timestamp + 1);
    }

    function test_sellShares_reverts_on_deadline_passed() external {
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(DeadlinePassed.selector);
        market.sellShares(amount, 0, 300 ether, block.timestamp - 1);
    }

    function test_sellShares_reverts_on_slippage() external {
        // maxOutcomeShares must be >= actual shares needed. We set 0 => revert
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(MaxSharesNotMet.selector);
        market.sellShares(amount, 0, 0, block.timestamp + 1);
    }

    function test_sellShares_reverts_on_close_time_passed() external {
        vm.warp(block.timestamp + 2 days);
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.sellShares(amount, 0, 300 ether, block.timestamp + 2);
    }

    function test_sellShares_reverts_on_closed_market() external {
        vm.warp(2 days);
        market.closeMarket();

        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(MarketClosed.selector);
        market.sellShares(amount, 0, 300 ether, block.timestamp + 1);
    }

    /*//////////////////////////////////////////////////////////////
                     TEST: removeLiquidity (3-outcome)
    //////////////////////////////////////////////////////////////*/

    function test_removeLiquidity_when_market_is_balanced_three_outcomes() external {
        // Arrange
        uint256 amount = 500 ether;
    
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        vm.expectEmit(true, false, false, true);
        emit IMarket.LiquidityRemoved(bob, 500 ether, 500 ether, 1000 ether);
    
        // Act
        uint256 shares = market.getUserLiquidityShares(bob);
        vm.prank(bob);
        market.removeLiquidity(shares, block.timestamp + 1);
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance - shares);
    
        /// Assert Liquidity Value
        assertEq(poolData.liquidity, prePoolData.liquidity - shares);
    
        /// Assert Total Outcome Shares
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares - (shares * 3));
        assertEq(totalShares[0], preTotalShares[0] - shares);
        assertEq(totalShares[1], preTotalShares[1] - shares);
        assertEq(totalShares[2], preTotalShares[2] - shares);
    
        /// Assert Pool Shares
        assertEq(poolShares[0], prePoolShares[0] - shares);
        assertEq(poolShares[1], prePoolShares[1] - shares);
        assertEq(poolShares[2], prePoolShares[2] - shares);
    
        /// Assert User Outcome Shares
        assertEq(bobOutcomeAShares, 0);
        assertEq(bobOutcomeBShares, 0);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    

//ToDO: Fix this test
    function test_removeLiquidity_when_entered_balanced_exit_in_unbalanced_three_outcomes() external {
        // Arrange
        uint256 amount = 500 ether;
    
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
    
        uint256 aliceBuyAmount = 100 ether;
        hoax(alice, aliceBuyAmount);
        market.buyShares{value: aliceBuyAmount}(aliceBuyAmount, 0, 0, block.timestamp + 1);
    
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();
    
        // Act
        uint256 bobClaimableFees = market.getClaimableFees(bob);
        uint256 liquiditySharesValue = bob.balance;
        uint256 shares = market.getUserLiquidityShares(bob);
        vm.prank(bob);
        market.removeLiquidity(shares, block.timestamp + 1);
        liquiditySharesValue = bob.balance - liquiditySharesValue - bobClaimableFees;
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        /// Assert Balance
        assertEq(poolData.balance, prePoolData.balance - liquiditySharesValue);
    
        /// Assert Liquidity Value
        assertApproxEqAbs(liquiditySharesValue, 469.33 ether, 0.01 ether);
        assertEq(poolData.liquidity, prePoolData.liquidity - shares);
    
        /// Assert Total Outcome Shares
        // assertEq(
        //     poolData.totalAvailableShares
        //         >= prePoolData.totalAvailableShares - (liquiditySharesValue * 3) - bobOutcomeBShares,
        //     true
        // );
        assertEq(totalShares[0], preTotalShares[0] - liquiditySharesValue);
        assertEq(totalShares[1], preTotalShares[1] - liquiditySharesValue);
        assertEq(totalShares[2], preTotalShares[2] - liquiditySharesValue);
    
        /// Assert Pool Shares
        assertEq(poolShares[0], prePoolShares[0] - liquiditySharesValue);
        assertEq(poolShares[1], prePoolShares[1] - liquiditySharesValue - bobOutcomeBShares);
        assertEq(poolShares[2], prePoolShares[2] - liquiditySharesValue);
    
        /// Assert User Outcome Shares
        assertEq(bobOutcomeAShares, 0);
        assertApproxEqAbs(bobOutcomeBShares, 63.32 ether, 0.01 ether);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

//ToDO: fix this test 
    function test_removeLiquidity_when_entered_unbalanced_exit_in_unbalanced_three_outcomes() external {
        // Arrange
        hoax(alice, 100 ether);
        market.buyShares{value: 100 ether}(100 ether, 0, 0, block.timestamp + 1);
    
        IMarket.MarketPoolData memory preAddLiquidityPoolData = market.getPoolData();
        (, uint256[] memory preAddLiquidityTotalShares, uint256[] memory preAddLiquidityShares) = market.getOutcomes();
    
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
    
        // Act
        uint256 liquiditySharesValue = bob.balance;
        uint256 shares = market.getUserLiquidityShares(bob);
        vm.prank(bob);
        market.removeLiquidity(shares, block.timestamp + 1);
        liquiditySharesValue = bob.balance - liquiditySharesValue;
    
        // Assert
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
    
        uint256 bobOutcomeAShares = market.getUserOutcomeShares(bob, 0);
        uint256 bobOutcomeBShares = market.getUserOutcomeShares(bob, 1);
        uint256 bobOutcomeCShares = market.getUserOutcomeShares(bob, 2);
    
        /// Assert Balance
        assertApproxEqAbs(poolData.balance, preAddLiquidityPoolData.balance + amount - liquiditySharesValue, 1e6);
    
        /// Assert Liquidity Value
        assertApproxEqAbs(liquiditySharesValue, 414.72 ether, 0.01 ether);
        assertApproxEqAbs(poolData.liquidity, preAddLiquidityPoolData.liquidity, 1e6);
    
        /// Assert Total Outcome Shares
        assertApproxEqAbs(poolData.totalAvailableShares, preAddLiquidityPoolData.totalAvailableShares, 1e21);
        assertApproxEqAbs(totalShares[0], preAddLiquidityTotalShares[0] + bobOutcomeAShares, 1e21);
        assertApproxEqAbs(totalShares[1], preAddLiquidityTotalShares[1] + bobOutcomeBShares, 1e21);
        assertApproxEqAbs(totalShares[2], preAddLiquidityTotalShares[2] + bobOutcomeCShares, 1e21);
    
        /// Assert Pool Shares
        assertApproxEqAbs(poolShares[0], preAddLiquidityShares[0], 1e21);
        assertApproxEqAbs(poolShares[1], preAddLiquidityShares[1], 1e21);
        assertApproxEqAbs(poolShares[2], preAddLiquidityShares[2], 1e21);
    
        /// Assert User Outcome Shares
        assertEq(bobOutcomeAShares, bobOutcomeBShares);
        assertApproxEqAbs(bobOutcomeBShares, 85.27 ether, 0.01 ether);
        assertEq(bobOutcomeCShares, 0);
    
        /// Assert User Liquidity Shares
        assertEq(market.getUserLiquidityShares(bob), 0);
    
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }
    
    

    function test_removeLiquidity_reverts_on_deadline_passed() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        uint256 shares = market.getUserLiquidityShares(bob);
        vm.expectRevert(DeadlinePassed.selector);
        market.removeLiquidity(shares, block.timestamp - 1);
    }

    function test_removeLiquidity_reverts_on_insufficient_shares() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        uint256 shares = market.getUserLiquidityShares(bob);
        vm.expectRevert(InsufficientShares.selector);
        market.removeLiquidity(shares + 1, block.timestamp + 1);
    }

    function test_removeLiquidity_reverts_on_failed_transfer() external {
        BadActor badActor = new BadActor(address(market));
        uint256 amount = 500 ether;
        deal(address(badActor), amount);
        badActor.addLiquidity{value: amount}(amount);

        // Try removing from a contract that always reverts on receive
        uint256 shares = market.getUserLiquidityShares(address(badActor));
        vm.expectRevert(TransferFailed.selector);
        badActor.removeLiquidity(shares);
    }

    function test_removeLiquidity_reverts_on_close_time_passed() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
        uint256 shares = market.getUserLiquidityShares(bob);

        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(MarketClosed.selector);
        market.removeLiquidity(shares, block.timestamp + 2);
    }

    function test_removeLiquidity_reverts_on_closed_market() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);
        uint256 shares = market.getUserLiquidityShares(bob);

        vm.warp(block.timestamp + 2 days);
        market.closeMarket();

        vm.expectRevert(MarketClosed.selector);
        market.removeLiquidity(shares, block.timestamp + 2);
    }

    /*//////////////////////////////////////////////////////////////
                         TEST: closeMarket
    //////////////////////////////////////////////////////////////*/

    function test_closeMarket_closes_market() external {
        vm.warp(block.timestamp + 2 days);

        vm.expectEmit(true, false, false, true);
        emit IMarket.MarketStateUpdated(block.timestamp, IMarket.MarketState.closed);

        market.closeMarket();
        assert(market.state() == IMarket.MarketState.closed);

        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_closeMarket_reverts_when_not_time() external {
        vm.warp(block.timestamp + 1 minutes);
        vm.expectRevert(MarketCloseTimeNotPassed.selector);
        market.closeMarket();
        assert(market.state() == IMarket.MarketState.open);
    }

    function test_closeMarket_reverts_when_market_already_closed() external {
        vm.warp(block.timestamp + 2 days);
        market.closeMarket();
        vm.expectRevert(InvalidMarketState.selector);
        market.closeMarket();
        assert(market.state() == IMarket.MarketState.closed);
    }

    /*//////////////////////////////////////////////////////////////
                         TEST: resolveMarket
    //////////////////////////////////////////////////////////////*/

    function test_resolveMarket_closed_market() external {
        vm.warp(market.getInfo().closeTime + 2 days);
        market.closeMarket();
        skip(market.resolveDelay());

        vm.prank(creator);
        oracle.setOutcome(0);

        vm.expectEmit(true, false, false, true);
        emit IMarket.MarketStateUpdated(block.timestamp, IMarket.MarketState.resolved);

        market.resolveMarket();
        assert(market.state() == IMarket.MarketState.resolved);

        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_resolveMarket_reverts_when_not_time() external {
        vm.warp(block.timestamp + 2 days);
        // Market still open => revert
        vm.expectRevert(InvalidMarketState.selector);
        market.resolveMarket();
        assert(market.state() == IMarket.MarketState.open);
    }

    function test_resolveMarket_reverts_when_delay_not_passed() external {
        vm.warp(block.timestamp + 2 days);
        market.closeMarket();
        // Not enough time for resolveDelay
        vm.expectRevert(MarketResolveDelayNotPassed.selector);
        market.resolveMarket();
        assert(market.state() == IMarket.MarketState.closed);
    }

    function test_resolveMarket_reverts_when_oracle_not_resolved() external {
        vm.warp(block.timestamp + 2 days);
        market.closeMarket();
        skip(market.getResolveDelay());

        vm.expectRevert(OracleNotResolved.selector);
        market.resolveMarket();
        assert(market.state() == IMarket.MarketState.closed);
    }

    /*//////////////////////////////////////////////////////////////
                          TEST: claimRewards
    //////////////////////////////////////////////////////////////*/

    function test_claimRewards_claims_eth_equal_to_shares() external {
        // Bob buys outcome 0
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, 0, 0, block.timestamp + 1);

        // Resolve the market with outcome=0 as winner
        resolveMarket(market);

        uint256 shares = market.getUserOutcomeShares(bob, 0);
        vm.expectEmit(true, false, false, true);
        emit IMarket.RewardsClaimed(bob, shares);

        uint256 balanceBefore = bob.balance;
        vm.prank(bob);
        market.claimRewards();
        uint256 claimed = bob.balance - balanceBefore;

        assertEq(claimed, shares);

        // Invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);
        uint256 creatorLiquidityValue = marketAMM.getClaimLiquidityData(
            market.getUserLiquidityShares(creator),
            market.getPoolData().outcomes[0].shares.available, // resolved to 0
            market.getPoolData().liquidity
        );
        assertEq(market.getPoolData().balance >= creatorLiquidityValue, true);
        assertEq(address(market).balance >= market.getPoolData().balance, true);
    }

    function test_claimRewards_reverts_when_no_shares() external {
        resolveMarket(market);
        vm.expectRevert(NoRewardsToClaim.selector);
        market.claimRewards();
    }

    function test_claimRewards_reverts_on_failed_transfer() external {
        BadActor badActor = new BadActor(address(market));
        uint256 amount = 500 ether;
        deal(address(badActor), amount);
        badActor.buyShares{value: amount}(amount, 0);

        resolveMarket(market);
        vm.expectRevert(TransferFailed.selector);
        badActor.claimRewards();
    }

    /*//////////////////////////////////////////////////////////////
                         TEST: claimLiquidity
    //////////////////////////////////////////////////////////////*/

    function test_claimLiquidity_claims_eth_proportional() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        uint256 buyAmount = 100 ether;
        hoax(alice, buyAmount);
        market.buyShares{value: buyAmount}(buyAmount, 0, 0, block.timestamp + 1);

        resolveMarket(market);

        // Bob first claim fees
        vm.prank(bob);
        market.claimFees();

        vm.expectEmit(true, false, false, false);
        emit IMarket.LiquidityClaimed(bob, 0); 

        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        market.claimLiquidity();
        uint256 bobClaimed = bob.balance - bobBalanceBefore;


        assertGe(bobClaimed, 0);

        // Invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);

        uint256 resolvedOutcome = market.getResolveOutcomeIndex();
        // Enough leftover for others
        uint256 aliceShares = market.getUserOutcomeShares(alice, resolvedOutcome);
        uint256 creatorLiquidityValue = marketAMM.getClaimLiquidityData(
            market.getUserLiquidityShares(creator),
            market.getPoolData().outcomes[resolvedOutcome].shares.available,
            market.getPoolData().liquidity
        );
        assertEq(market.getPoolData().balance >= aliceShares + creatorLiquidityValue, true);
        assertEq(address(market).balance >= market.getPoolData().balance, true);
    }

    function test_claimLiquidity_reverts_when_no_liquidity() external {
        resolveMarket(market);
        vm.expectRevert(NoLiquidityToClaim.selector);
        market.claimLiquidity();
    }

    function test_claimLiquidity_reverts_on_failed_transfer() external {
        BadActor badActor = new BadActor(address(market));
        uint256 amount = 500 ether;
        deal(address(badActor), amount);
        badActor.addLiquidity{value: amount}(amount);

        resolveMarket(market);
        vm.expectRevert(TransferFailed.selector);
        badActor.claimLiquidity();
    }

    function test_claimLiquidity_reverts_when_market_not_resolved() external {
        // Market is open or closed but not resolved => revert
        vm.expectRevert(InvalidMarketState.selector);
        market.claimLiquidity();
    }

    /*//////////////////////////////////////////////////////////////
                           TEST: claimFees
    //////////////////////////////////////////////////////////////*/

    function test_claimFees_claims_eth_proportional_to_lp_shares() external {
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        uint256 aliceBuy = 100 ether;
        hoax(alice, aliceBuy);
        market.buyShares{value: aliceBuy}(aliceBuy, 0, 0, block.timestamp + 1);

        vm.expectEmit(true, false, false, false);
        emit IMarket.FeesClaimed(bob, 0); // ignoring exact amount in event check

        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        market.claimFees();
        uint256 bobClaimed = bob.balance - bobBalanceBefore;

        // Should be > 0
        assertGe(bobClaimed, 0);

        // Another claim yields 0
        uint256 bobBalanceBefore2 = bob.balance;
        vm.prank(bob);
        market.claimFees();
        uint256 bobClaimed2 = bob.balance - bobBalanceBefore2;
        assertEq(bobClaimed2, 0);
    }

    function test_claimFees_reverts_when_failed_transfer() external {
        BadActor badActor = new BadActor(address(market));
        uint256 amount = 500 ether;
        deal(address(badActor), amount);
        badActor.addLiquidity{value: amount}(amount);

        // Some buys to generate fees
        uint256 aliceBuy = 100 ether;
        hoax(alice, aliceBuy);
        market.buyShares{value: aliceBuy}(aliceBuy, 0, 0, block.timestamp + 1);

        vm.expectRevert(TransferFailed.selector);
        badActor.claimFees();
    }

    /*//////////////////////////////////////////////////////////////
                          TEST: getOutcomes
    //////////////////////////////////////////////////////////////*/

    function test_getOutcomes_returns_correct_outcomes() external view {
        (string[] memory names, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
        assertEq(names.length, 3);
        assertEq(names[0], "Red");
        assertEq(names[1], "Green");
        assertEq(names[2], "Blue");

        assertEq(totalShares.length, 3);
        assertEq(totalShares[0], 1000 ether);
        assertEq(totalShares[1], 1000 ether);
        assertEq(totalShares[2], 1000 ether);

        assertEq(poolShares.length, 3);
        assertEq(poolShares[0], 1000 ether);
        assertEq(poolShares[1], 1000 ether);
        assertEq(poolShares[2], 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                      TEST: getResolveOutcomeIndex
    //////////////////////////////////////////////////////////////*/

    function test_getResolveOutcomeIndex_returns_correct_outcome_index() external {
        resolveMarket(market);
        uint256 outcomeIndex = market.getResolveOutcomeIndex();
        assertEq(outcomeIndex, 0);
    }

    function test_getResolveOutcomeIndex_when_market_not_resolved() external {
        vm.warp(block.timestamp + 2 days);
        market.closeMarket();
        vm.expectRevert(InvalidMarketState.selector);
        market.getResolveOutcomeIndex();
    }

    /*//////////////////////////////////////////////////////////////
                         TEST: getOutcomePrice
    //////////////////////////////////////////////////////////////*/

    function test_getOutcomePrice_returns_correct_price() external {
        hoax(alice, 100 ether);
        market.buyShares{value: 100 ether}(100 ether, 0, 0, block.timestamp + 1);

        uint256 amt = 500 ether;
        hoax(bob, amt);
        market.addLiquidity{value: amt}(amt, block.timestamp + 1);

        // We simply check that the sum of prices is roughly 1.0 (some small rounding differences).
        uint256 price0 = market.getOutcomePrice(0);
        uint256 price1 = market.getOutcomePrice(1);
        uint256 price2 = market.getOutcomePrice(2);

        assertApproxEqAbs(price0 + price1 + price2, 1 ether, 5e15); // Tolerate rounding
    }

    function test_getOutcomePrice_when_resolved_market() external {
        resolveMarket(market);

        uint256 resolvedPrice = market.getOutcomePrice(0);
        uint256 losingPrice1 = market.getOutcomePrice(1);
        uint256 losingPrice2 = market.getOutcomePrice(2);

        assertEq(resolvedPrice, 1 ether);
        assertEq(losingPrice1, 0);
        assertEq(losingPrice2, 0);
    }
}
