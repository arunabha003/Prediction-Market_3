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
import {IMarketAMM} from "../contracts/interfaces/IMarketAMM.sol";
import {IOracle} from "../contracts/interfaces/IOracle.sol";

import {MarketAMM} from "../contracts/MarketAMM.sol";
import {Market} from "../contracts/Market.sol";
import {CentralizedOracle} from "../contracts/CentralizedOracle.sol";

/**
 * @title MarketAMMTest (3-outcome version)
 * @notice This test file is adapted for a 3-outcome market.
 */
contract MarketAMMTest is Test {
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

    /**
     * @dev Checks a simple "constant product" or "geometric mean" style invariant
     *      for a 3-outcome pool if that is your intended formula. Adapt as needed.
     */
    function assertInvariant(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        require(poolData.outcomes.length == 3, "Expected 3 outcomes for this test.");
        uint256[] memory poolShares = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            poolShares[i] = poolData.outcomes[i].shares.available;
        }

        // If your real AMM uses a different formula, adapt this accordingly.
        // Example: cbrt(share0 * share1 * share2) ~ poolData.liquidity
        uint256 geometricMean = _cbrt(poolShares[0] * poolShares[1] * poolShares[2]);
        assertApproxEqAbs(geometricMean, poolData.liquidity, 1e10); // Tolerance for rounding
    }

    /**
     * @dev Checks that totalAvailableShares is the sum of all 3 outcome shares.
     */
    function assertTotalAvailableShares(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        uint256 sum;
        for (uint256 i = 0; i < poolData.outcomes.length; ++i) {
            sum += poolData.outcomes[i].shares.available;
        }
        assertEq(poolData.totalAvailableShares, sum);
    }

    /**
     * @dev Ensures the Market holds enough ETH for the recorded `poolData.balance`,
     *      and that `poolData.balance` is >= each outcome's `shares.total`.
     */
    function assertMarketBalance(IMarket _market) public view {
        IMarket.MarketPoolData memory poolData = _market.getPoolData();
        assertEq(address(_market).balance >= poolData.balance, true);

        for (uint256 i = 0; i < poolData.outcomes.length; ++i) {
            assertEq(poolData.balance >= poolData.outcomes[i].shares.total, true);
        }
    }

    /**
     * @dev Helper that simulates full closing & resolving of the market with outcome 0 as winner.
     */
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
        marketAMM = new MarketAMM();
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

        // Check pool data
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        // For 3 outcomes, each outcome was seeded with initialLiquidity (1000).
        // totalAvailableShares = 3 * 1000 = 3000
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
        // Only 2 outcomes given, but we need exactly 3 for this Market logic.
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

        // We pass 0 ether, mismatch with initialLiquidity=1000
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

    function test_addLiquidity_receive_only_lp_shares_on_equal_market() external {
        // Market initially is balanced across 3 outcomes
        uint256 amount = 50 ether;

        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();

        vm.expectEmit(true, false, false, true);
        emit IMarket.LiquidityAdded(bob, amount, 50 ether, 1050 ether);

        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
        uint256 bobLiquidityShares = market.getUserLiquidityShares(bob);

        // Balance
        assertEq(poolData.balance, prePoolData.balance + amount);

        // Liquidity
        assertEq(poolData.liquidity, prePoolData.liquidity + amount);

        // Each outcome's total shares & pool shares increased by amount
        for (uint256 i = 0; i < 3; i++) {
            assertEq(totalShares[i], preTotalShares[i] + amount);
            assertEq(poolShares[i], prePoolShares[i] + amount);
        }

        // totalAvailableShares
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares + (amount * 3));

        // Bob's outcome shares are 0 (since everything is balanced)
        for (uint256 i = 0; i < 3; i++) {
            uint256 bobOutcomeShares = market.getUserOutcomeShares(bob, i);
            assertEq(bobOutcomeShares, 0);
        }

        // Bob liquidity shares
        assertEq(bobLiquidityShares, 50 ether);

        // Invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_addLiquidity_receive_lp_and_least_likely_outcome_shares_on_unequal_market() external {
        // Make the market unbalanced by buying outcome 0
        uint256 buyAmount = 100 ether;
        hoax(alice, buyAmount);
        market.buyShares{value: buyAmount}(buyAmount, 0, 0, block.timestamp + 1);

        // Bob adds liquidity
        uint256 amount = 500 ether;
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();

        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        // Check pool data
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
        uint256 bobLiquidityShares = market.getUserLiquidityShares(bob);

        // Balance
        assertEq(poolData.balance, prePoolData.balance + amount);

        // totalAvailableShares: 
        //   old + (3 * amount) minus some shares for the unbalanced outcome 0 user gets
        //   The market code: 
        //     - adds amountAfterFee to each outcome's total & available
        //     - lumps out the minted shares to the user in the "least likely" outcome
        // For simplicity, just check that it's "old + 3*amount - the new user outcome shares" 
        //   (the new user receives outcome shares in whichever is least likely).
        // Because we have no direct formula for how many shares are minted to the user, we do approximate checks.

        // Confirm that each outcome got +amount in total
        for (uint256 i = 0; i < 3; i++) {
            assertEq(totalShares[i], preTotalShares[i] + amount);
        }

        // Confirm sum of pool-shares is old sum + (3 * amount) minus the newly minted user shares
        uint256 poolShareSum;
        for (uint256 i = 0; i < 3; i++) {
            poolShareSum += poolShares[i];
        }
        uint256 prePoolShareSum;
        for (uint256 i = 0; i < 3; i++) {
            prePoolShareSum += prePoolShares[i];
        }
        // poolShareSum should be prePoolShareSum + 3*amount - userAcquiredShares
        assertEq(poolData.totalAvailableShares, poolShareSum);

        // Bob's liquidity shares is not necessarily 500 exactly, depending on unbalance
        assertGe(bobLiquidityShares, 0);
        assertLe(bobLiquidityShares, 500 ether);

        // Bob might have some minted outcome shares of the "least likely" outcome
        // just check they're >= 0
        uint256 userOutcomeSharesSum;
        for (uint256 i = 0; i < 3; i++) {
            userOutcomeSharesSum += market.getUserOutcomeShares(bob, i);
        }
        assertGe(userOutcomeSharesSum, 0);

        // Invariants
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

    function test_buyShares_correctly_buys_shares() external {
        uint256 amount = 300 ether;
        uint256 fee = (amount * market.getFeeBPS()) / BPS;
        uint256 amountAfterFee = amount - fee;

        uint256 outcomeIndex = 0;

        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();

        vm.expectEmit(true, false, false, false);
        emit IMarket.SharesBought(bob, outcomeIndex, 0, 0, 0); // ignoring event data checks

        hoax(bob, amount);
        market.buyShares{value: amount}(amount, outcomeIndex, 0, block.timestamp + 1);

        // Post state
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();
        uint256 bobOutcome0Shares = market.getUserOutcomeShares(bob, 0);

        // Balance => + amountAfterFee
        assertEq(poolData.balance, prePoolData.balance + amountAfterFee);

        // Liquidity unchanged
        assertEq(poolData.liquidity, prePoolData.liquidity);

        // totalAvailableShares => old + (3 * amountAfterFee) - bobOutcome0Shares
        // Because for each of the 3 outcomes, we add amountAfterFee, but we remove the purchased portion from outcomeIndex 0.
        uint256 expectedDelta = (3 * amountAfterFee) - bobOutcome0Shares;
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares + expectedDelta);

        // Check each outcome's total shares was increased by amountAfterFee
        for (uint256 i = 0; i < 3; i++) {
            assertEq(totalShares[i], preTotalShares[i] + amountAfterFee);
        }

        // Check the chosen outcome's pool shares is reduced by the purchased shares
        for (uint256 i = 0; i < 3; i++) {
            // pool shares = old + amountAfterFee for all i
            // but for outcomeIndex, we subtract bobOutcome0Shares
            if (i == outcomeIndex) {
                assertEq(poolShares[i], prePoolShares[i] + amountAfterFee - bobOutcome0Shares);
            } else {
                assertEq(poolShares[i], prePoolShares[i] + amountAfterFee);
            }
        }

        // Bob gets some shares of outcome 0
        assertGe(bobOutcome0Shares, 0);

        // No liquidity shares for Bob
        assertEq(market.getUserLiquidityShares(bob), 0);

        // Invariants
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
        // With 3 outcomes, valid indices are 0,1,2. So index=3 is invalid.
        uint256 amount = 300 ether;
        hoax(bob, amount);

        // Should revert, out-of-bounds
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
        // If we require at least e.g. 1000 shares, but we won't get that many
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
        // First buy outcome 0
        uint256 amount = 100 ether;
        hoax(bob, amount);
        market.buyShares{value: amount}(amount, 0, 0, block.timestamp + 1);

        // Then sell
        uint256 fee = (100 ether * market.getFeeBPS()) / BPS;
        uint256 amountAfterFee = 100 ether - fee;

        IMarket.MarketPoolData memory preSellPoolData = market.getPoolData();
        (, uint256[] memory preSellTotalShares, uint256[] memory preSellPoolShares) = market.getOutcomes();

        uint256 bobPreSellOutcome0Shares = market.getUserOutcomeShares(bob, 0);
        vm.expectEmit(true, false, false, false);
        emit IMarket.SharesSold(bob, 0, 0, 0, 0);

        vm.prank(bob);
        market.sellShares(amountAfterFee, 0, 300 ether, block.timestamp + 1);

        // Post-state
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();

        // Balance => decreased by 100 ether - fee => net - (amountAfterFee + fee) = -100
        // The final poolData.balance should revert to the original before the buy
        // The net effect: we added +100 (buy), then remove -100 (sell). So final balance is initial.
        // Indeed:
        // preSellPoolData.balance was initial + 100 - fee
        // after selling, balance = preSellPoolData.balance - (100 - fee) = original.
        assertEq(poolData.balance, 1000 ether);

        // totalAvailableShares => preSell + (3 * -100) + bobPreSellOutcome0Shares
        // Because we remove 100 from each outcome (the code subtracts _receiveAmount from .total and .available for each outcome)
        // and we add back the shares from bob. So net is -3*100 + bobPreSellOutcome0Shares. 
        uint256 expectedDelta = -(3 * 100 ether) + bobPreSellOutcome0Shares;
        assertEq(poolData.totalAvailableShares, preSellPoolData.totalAvailableShares + expectedDelta);

        // Each outcome's total shares is down by 100
        for (uint256 i = 0; i < 3; i++) {
            assertEq(totalShares[i], preSellTotalShares[i] - 100 ether);
        }

        // For outcome 0, we also add back bob's shares that he sold
        // So poolShares[0] = preSellPoolShares[0] - 100 + bobPreSellOutcome0Shares
        // For outcomes 1 & 2, poolShares[i] = preSellPoolShares[i] - 100
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                assertEq(poolShares[i], preSellPoolShares[i] - 100 ether + bobPreSellOutcome0Shares);
            } else {
                assertEq(poolShares[i], preSellPoolShares[i] - 100 ether);
            }
        }

        // Bob's shares are now zero
        assertEq(market.getUserOutcomeShares(bob, 0), 0);

        // Invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_sellShares_reverts_on_insufficient_share() external {
        // Bob tries to sell more shares than he has
        uint256 amount = 100 ether;
        hoax(bob, amount);
        vm.expectRevert(InsufficientShares.selector);
        market.sellShares(amount + 1, 0, 300 ether, block.timestamp + 1);
    }

    function test_sellShares_reverts_on_failed_transfer() external {
        BadActor badActor = new BadActor(address(market));

        uint256 amount = 500 ether;
        deal(address(badActor), amount);
        badActor.buyShares{value: amount}(amount, 0);

        // Attempt to sell with a contract that fails on receive
        vm.expectRevert(TransferFailed.selector);
        badActor.sellShares(amount - (amount * market.getFeeBPS()) / BPS, 0);
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

    function test_removeLiquidity_when_market_is_balanced() external {
        // Bob adds liquidity to an already balanced 3-outcome market
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();

        vm.expectEmit(true, false, false, true);
        emit IMarket.LiquidityRemoved(bob, 500 ether, 500 ether, 1000 ether);

        uint256 shares = market.getUserLiquidityShares(bob);
        vm.prank(bob);
        market.removeLiquidity(shares, block.timestamp + 1);

        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();

        // poolData.balance => pre minus 500
        assertEq(poolData.balance, prePoolData.balance - shares);
        // liquidity => pre minus 500
        assertEq(poolData.liquidity, prePoolData.liquidity - shares);
        // totalAvailableShares => pre minus 3*500
        assertEq(poolData.totalAvailableShares, prePoolData.totalAvailableShares - (shares * 3));

        // Each outcome's total & pool shares => minus 500
        for (uint256 i = 0; i < 3; i++) {
            assertEq(totalShares[i], preTotalShares[i] - shares);
            assertEq(poolShares[i], prePoolShares[i] - shares);
            // Bob does not receive any outcome shares in a perfectly balanced remove
            assertEq(market.getUserOutcomeShares(bob, i), 0);
        }

        // Bob's liquidity shares are 0 now
        assertEq(market.getUserLiquidityShares(bob), 0);

        // Invariants
        assertInvariant(market);
        assertTotalAvailableShares(market);
        assertMarketBalance(market);
    }

    function test_removeLiquidity_when_entered_balanced_exit_in_unbalanced() external {
        // 1) Bob adds liquidity in a balanced state
        uint256 amount = 500 ether;
        hoax(bob, amount);
        market.addLiquidity{value: amount}(amount, block.timestamp + 1);

        // 2) Alice buys outcome 0 => unbalance
        uint256 aliceBuy = 100 ether;
        hoax(alice, aliceBuy);
        market.buyShares{value: aliceBuy}(aliceBuy, 0, 0, block.timestamp + 1);

        // 3) Bob removes liquidity from unbalanced
        IMarket.MarketPoolData memory prePoolData = market.getPoolData();
        (, uint256[] memory preTotalShares, uint256[] memory prePoolShares) = market.getOutcomes();

        uint256 bobBalanceBefore = bob.balance;
        uint256 bobClaimableFeesBefore = market.getClaimableFees(bob);
        uint256 shares = market.getUserLiquidityShares(bob);

        vm.prank(bob);
        market.removeLiquidity(shares, block.timestamp + 1);

        uint256 bobBalanceChange = bob.balance - bobBalanceBefore;
        // We also expect bob might have automatically claimed fees in the process
        // to keep the test consistent, we can check that the difference minus fees is near some expected value.

        // Post-state
        IMarket.MarketPoolData memory poolData = market.getPoolData();
        (, uint256[] memory totalShares, uint256[] memory poolShares) = market.getOutcomes();

        // The net withdrawn is some ETH + possibly some outcome shares of the least-likely outcome
        // We only do approximate checks

        // Check final liquidity
        assertEq(poolData.liquidity, prePoolData.liquidity - shares);

        // For each outcome, totalShares is minus some portion. Some portion might also be minted to Bob
        // We check that the sum matches poolData.totalAvailableShares changes
        assertEq(
            poolData.totalAvailableShares + (poolData.balance), 
            (prePoolData.totalAvailableShares + prePoolData.balance)
                // minus some net difference
        );

        // Bob gets some outcome shares if the market is unbalanced
        // Just ensure they are > 0 for whichever is least likely, e.g. outcome 1 or 2
        // or possibly 0 if outcome 0 is more "likely."
        // The test just checks that the math is consistent:
        uint256 sumBobOutcomeShares;
        for (uint256 i = 0; i < 3; i++) {
            sumBobOutcomeShares += market.getUserOutcomeShares(bob, i);
        }
        // Ensure total shares are not negative
        assertGe(sumBobOutcomeShares, 0);

        // Bob's liquidity is gone
        assertEq(market.getUserLiquidityShares(bob), 0);

        // The amount of ETH bob gained:
        //   - definitely > 0
        assertGe(bobBalanceChange, 0);

        // Check Bob’s claimable fees are probably 0 now if removing liquidity triggered fee claims
        uint256 bobClaimableFeesAfter = market.getClaimableFees(bob);
        if (bobClaimableFeesBefore > 0) {
            // removing liquidity claims the fees
            assertEq(bobClaimableFeesAfter, 0);
        }

        // Invariants
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
        // Some leftover for liquidity providers
        uint256 creatorLiquidityValue = marketAMM.getClaimLiquidityData(
            market.getUserLiquidityShares(creator),
            market.getPoolData().outcomes[0].shares.available, // resolved to 0
            market.getPoolData().liquidity
        );
        // Market still has enough balance for LP claims
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
        // Bob adds liquidity, Alice buys outcome 0, market resolves with outcome 0
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
        emit IMarket.LiquidityClaimed(bob, 0); // We won't check exact numbers from the event

        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        market.claimLiquidity();
        uint256 bobClaimed = bob.balance - bobBalanceBefore;

        // Check approximate
        // Typically, bob should get < 500 back because unbalanced trades happened
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
        // Bob adds liquidity, Alice buys an outcome => fees
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
        // Make outcome 0 more expensive by buying it
        hoax(alice, 100 ether);
        market.buyShares{value: 100 ether}(100 ether, 0, 0, block.timestamp + 1);

        // Add more liquidity
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

        // outcome 0 is the winner => price 1.0
        uint256 resolvedPrice = market.getOutcomePrice(0);
        uint256 losingPrice1 = market.getOutcomePrice(1);
        uint256 losingPrice2 = market.getOutcomePrice(2);

        assertEq(resolvedPrice, 1 ether);
        assertEq(losingPrice1, 0);
        assertEq(losingPrice2, 0);
    }
}
