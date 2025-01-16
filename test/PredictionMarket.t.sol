// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev A simple ERC20 token for testing the `PredictionMarket` "requiredBalance" logic.
 */
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // Nothing special
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title PredictionMarketTest
 * A Foundry test contract covering major functionalities of PredictionMarket.
 */
contract PredictionMarketTest is Test {
    // ---------------------------------------
    // Test Contracts & Addresses
    // ---------------------------------------
    PredictionMarket public market;  // The PredictionMarket we’re testing
    MockERC20 public token;          // Mock ERC20 token to satisfy "requiredBalance"

    address public owner;   // Contract deployer
    address public alice;   // User 1
    address public bob;     // User 2
    address public carol;   // Another user

    // ---------------------------------------
    // Constants / Configuration
    // ---------------------------------------
    // 1% fee
    uint256 public constant FEE = 0.01 ether;  
    // For "mustHoldRequiredBalance"
    uint256 public constant REQUIRED_BALANCE = 1000e18;  
    // Test token initial mint
    uint256 public constant INITIAL_MINT = 10_000e18;  

    // Utility
    uint256 public constant ONE = 1e18;

    // ---------------------------------------
    // setUp()
    // ---------------------------------------
    function setUp() public {
        // Create addresses
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Deal them some ETH for gas usage
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);

        // Deploy mock ERC20 & mint tokens
        token = new MockERC20("Mock Token", "MOCK");
        token.mint(alice, INITIAL_MINT);
        token.mint(bob, INITIAL_MINT);
        token.mint(carol, INITIAL_MINT);

        // Deploy PredictionMarket
        // For the constructor: constructor(uint256 _fee, IERC20 _token, uint256 _requiredBalance)
        market = new PredictionMarket(FEE, IERC20(token), REQUIRED_BALANCE);
    }

    // ---------------------------------------
    // Helpers
    // ---------------------------------------


    /**
     * @dev Create a new binary market with initial liquidity.
     * @param from The user creating the market (prank this address)
     * @param stakeETH The amount of ETH to seed as initial liquidity.
     * @param closesInSec How many seconds until it closes from now.
     */
    function createTestMarket(address from, uint256 stakeETH, uint256 closesInSec)
        public
        returns (uint256 marketId)
    {
        vm.startPrank(from);

        // Info for creation
        string memory question = "Will it rain tomorrow?";
        string memory imageUrl = "https://example.com/image.png";
        uint256 closesAt = block.timestamp + closesInSec;
        address arbitrator = address(0x1234); // Arbitrary

        marketId = market.createMarket{value: stakeETH}(
            question,
            imageUrl,
            closesAt,
            arbitrator,
            2 // 2 outcomes (binary)
        );
        vm.stopPrank();
    }

    // ---------------------------------------
    // Tests
    // ---------------------------------------

    // 1) Market Creation
    function testCreateMarketSuccess() public {
        // Create with 1 ETH initial stake
        uint256 closesInSec = 1 days;
        uint256 marketId = createTestMarket(alice, 1 ether, closesInSec);

        // Check basic data
        (
            PredictionMarket.MarketState state,
            uint256 closesAtTimestamp,
            uint256 liquidity,
            uint256 balance,
            uint256 sharesAvailable,
            int256 resolvedOutcome
        ) = market.getMarketData(marketId);

        // Should be open
        assertEq(uint(state), uint(PredictionMarket.MarketState.open), "MarketState != open");
        // Liquidity and balance should match initial stake
        assertEq(liquidity, 1 ether, "Liquidity mismatch");
        assertEq(balance, 1 ether, "Balance mismatch");
        // 2 outcomes => sharesAvailable should be 2 * 1 ETH = 2 ETH if the logic 
        // places "value" across each outcome. But see the code: 
        // The code might distribute shares in a certain way. 
        // The newly minted shares for each outcome: each outcome +1, total 2. 
        // But let's see. `_addSharesToMarket(marketId, value)` adds `value` shares to each outcome?
        // Actually, it adds `value` to each outcome => 2 outcomes => total = 2 * 1 = 2
        // So `sharesAvailable` = 2.
        // But remember the contract's code: 
        //    for i in outcomes => outcome.shares.available += shares
        // => 2 outcomes => total = 2 ETH in shares.
        // So let's confirm:
        assertEq(sharesAvailable, 2 ether, "sharesAvailable mismatch");
        // resolvedOutcome => -1 if not resolved
        assertEq(resolvedOutcome, -1, "Resolved outcome should be -1 (not resolved)");
    }

    function testCreateMarketInsufficientERC20Balance() public {
        // If a user doesn't have enough token balance to meet "requiredBalance", 
        // creation should revert. Let's drain Bob's tokens below requiredBalance.
        // The contract has `mustHoldRequiredBalance` for createMarket.
        vm.startPrank(bob);

        // Drain Bob's entire MOCK balance
        token.transfer(address(0xDEAD), token.balanceOf(bob));

        // Attempt to create
        vm.expectRevert("Sender must hold the required ERC20 balance");
        market.createMarket{value: 1 ether}(
            "Question?",
            "image.png",
            block.timestamp + 1 days,
            address(0x1111),
            2
        );

        vm.stopPrank();
    }

    // 2) Buying Shares
    function testBuyShares() public {
        // Create market with 1 ETH from Alice
        uint256 marketId = createTestMarket(alice, 1 ether, 1 days);

        // Bob buys outcomeId 0 with 0.3 ETH
        vm.startPrank(bob);
        uint256 bobBalanceBefore = bob.balance;
        
        // We'll do a mild check: 
        // We'll fetch calcBuyAmount just to see how many shares we'd get
        uint256 expectedShares = market.calcBuyAmount(0.3 ether, marketId, 0);
        // Now actually buy
        market.buy{value: 0.3 ether}(marketId, 0, expectedShares);

        // Check Bob's ETH spent ~0.3 (minus gas). We'll only check difference ignoring gas fees:
        uint256 bobBalanceAfter = bob.balance;
        assertEq(bobBalanceBefore - bobBalanceAfter, 0.3 ether, "Bob ETH spent mismatch");

        // Confirm Bob now holds outcome0 shares
        ( , uint256 bobOutcome0Shares, uint256 bobOutcome1Shares) =
            market.getUserMarketShares(marketId, bob);
        assertEq(bobOutcome0Shares, expectedShares, "Bob's outcome0 shares mismatch");
        assertEq(bobOutcome1Shares, 0, "Bob shouldn't hold outcome1 shares");

        vm.stopPrank();
    }

    // 3) Selling Shares
    function testSellShares() public {
        // Create a market
        uint256 marketId = createTestMarket(alice, 1 ether, 1 days);

        // Alice buys some outcome 0 shares
        vm.startPrank(alice);
        uint256 initialBuy = 0.5 ether;
        uint256 sharesBought = market.calcBuyAmount(initialBuy, marketId, 0);
        market.buy{value: initialBuy}(marketId, 0, sharesBought);
        vm.stopPrank();

        // Now Alice attempts to sell enough shares to receive 0.2 ETH
        vm.startPrank(alice);
        uint256 aliceBalBefore = alice.balance;

        uint256 desiredValue = 0.2 ether;
        uint256 sharesToSell = market.calcSellAmount(desiredValue, marketId, 0);
        
        // Approve a bit of slack for slippage
        market.sell(marketId, 0, desiredValue, sharesToSell + 1);

        uint256 aliceBalAfter = alice.balance;
        // She should gain about 0.2 ETH
        uint256 diff = aliceBalAfter - aliceBalBefore;
        // We'll allow some minor difference if fees are in play
        assertApproxEqAbs(diff, desiredValue, 1e14, "Alice's ETH after selling mismatch");
        vm.stopPrank();
    }

    // 4) Adding Liquidity
    function testAddLiquidity() public {
        uint256 marketId = createTestMarket(alice, 1 ether, 1 days);

        // Bob wants to add 1 more ETH to the liquidity pool
        vm.startPrank(bob);
        uint256 bobEthBefore = bob.balance;

        market.addLiquidity{value: 1 ether}(marketId);
        uint256 bobEthAfter = bob.balance;
        assertEq(bobEthBefore - bobEthAfter, 1 ether, "Bob didn't spend 1 ETH on addLiquidity");

        // Check Bob's liquidity shares
        (uint256 bobLiquidity, , ) = market.getUserMarketShares(marketId, bob);
        assertTrue(bobLiquidity > 0, "Bob has no liquidity shares?");

        vm.stopPrank();
    }

    // 5) Removing Liquidity
    function testRemoveLiquidity() public {
        uint256 marketId = createTestMarket(alice, 2 ether, 1 days);
        // Check initial liquidity shares for Alice
        (uint256 aliceLp, , ) = market.getUserMarketShares(marketId, alice);

        // Alice removes half her liquidity
        uint256 sharesToRemove = aliceLp / 2;
        vm.startPrank(alice);
        uint256 aliceBalBefore = alice.balance;

        market.removeLiquidity(marketId, sharesToRemove);

        uint256 aliceBalAfter = alice.balance;
        // She should get back ~1 ETH (the fraction). 
        // Fee might reduce it a bit, but let's ensure it's near 1 ETH
        uint256 diff = aliceBalAfter - aliceBalBefore;
        assertApproxEqAbs(diff, 1 ether, 1e14, "RemoveLiquidity: ETH mismatch");
        vm.stopPrank();
    }

    // 6) Market Resolution (non-voided) & Claim Winnings
    function testManualResolveMarketOutcomeAndClaimWinnings() public {
        // 1) Create market with a short closing time
        uint256 marketId = createTestMarket(alice, 2 ether, 2);
        
        // 2) Bob buys outcome 0 for 1 ETH
        vm.startPrank(bob);
        // We skip the 'minOutcomeSharesToBuy' slippage param for brevity
        market.buy{value: 1 ether}(marketId, 0, 1);
        vm.stopPrank();
    
        // 3) Advance time so the market goes from open -> closed
        skip(3);
    
        // 4) Force it from open -> closed by calling a function with timeTransitions
        market.getMarketData(marketId);
        // Now the market is 'closed'.
    
        // 5) Manually resolve to outcome 0 => closed -> resolved
        vm.prank(alice);
        market.manualResolveMarketOutcome(marketId, 0);
    
        // 6) Bob claims winnings
        vm.startPrank(bob);
        uint256 bobBalBefore = bob.balance;
    
        // Before we call claimWinnings, let's see how many outcome0 shares Bob has
        // Each winning share => 1 wei in a non-voided resolved market
        (, uint256 bobOutcome0Shares, ) = market.getUserMarketShares(marketId, bob);
    
        // We expect Bob’s final payout = bobOutcome0Shares (because 1 share => 1 wei)
        uint256 expectedPayout = bobOutcome0Shares;
    
        // Actually claim
        market.claimWinnings(marketId);
    
        // Check Bob’s actual ETH difference
        uint256 bobBalAfter = bob.balance;
        uint256 actualPayout = bobBalAfter - bobBalBefore;
    
        // Verify Bob's payout is approximately equal to the expected shares
        // We use Foundry's assertApproxEqAbs(...) or similar approach:
        // The last argument is an allowed delta (tolerance in wei)
        assertApproxEqAbs(
            actualPayout,
            expectedPayout,
            1e14, // e.g., tolerance of 0.0001 ETH in case of minor rounding
            "Bob's payout doesn't match his winning shares!"
        );
        vm.stopPrank();
    
        // We confirm Bob has indeed received what the contract calculates as winning.
    }
    
    // 7) Voided scenario & Claim Voided
    function testVoidedMarket() public {
        // 1) Create market with short close time (2 seconds)
        uint256 marketId = createTestMarket(bob, 2 ether, 2);
    
        // 2) Bob buys outcome 1 shares while the market is open
        vm.startPrank(bob);
        uint256 bobBuyAmount = 0.5 ether;
        uint256 expectedShares = market.calcBuyAmount(bobBuyAmount, marketId, 1);
        market.buy{value: bobBuyAmount}(marketId, 1, expectedShares);
        vm.stopPrank();
    
        // 3) Skip time to ensure market closes
        skip(3);
    
        // 4) Trigger timeTransitions to transition the market to 'closed'
        market.getMarketData(marketId); // Ensures the market transitions to 'closed'
    
        // 5) Manual resolve with an invalid outcomeId => triggers void
        vm.prank(alice);
        market.manualResolveMarketOutcome(marketId, 3); // Invalid outcomeId (>= 2 for binary) => voided
    
        // 6) Confirm market is voided
        bool isVoided = market.isMarketVoided(marketId);
        assertTrue(isVoided, "Market not recognized as voided");
    
        // 7) Bob claims voided outcome 1 shares
        vm.startPrank(bob);
        // Check Bob's outcome1 shares
        (, , uint256 bobOutcome1) = market.getUserMarketShares(marketId, bob);
        assertTrue(bobOutcome1 > 0, "Bob should have outcome1 shares");
    
        uint256 bobBalBefore = bob.balance;
        market.claimVoidedOutcomeShares(marketId, 1); // Claim for outcomeId 1
        uint256 bobBalAfter = bob.balance;
    
        // Ensure Bob received a payout for his voided shares
        assertTrue(bobBalAfter > bobBalBefore, "Bob didn't receive any voided share payout");
        vm.stopPrank();
    }
    
    

    function testVoidedMarketScenario() public {
        // Create fresh
        uint256 marketId = createTestMarket(alice, 2 ether, 2);

        // Bob buys outcome 1 for 0.5 ETH
        vm.startPrank(bob);
        market.buy{value: 0.5 ether}(marketId, 1, 1);
        vm.stopPrank();

        // skip so it closes
        skip(3);

        // manualResolve => outcomeId = 3 => void
        vm.prank(alice);
        market.manualResolveMarketOutcome(marketId, 3); // invalid => voided

        bool isVoided = market.isMarketVoided(marketId);
        assertTrue(isVoided, "Market not recognized as voided");

        // Bob claims voided outcome 1 shares
        vm.startPrank(bob);
        // check Bob's outcome1 shares
        (, , uint256 bobOutcome1) = market.getUserMarketShares(marketId, bob);
        assertTrue(bobOutcome1 > 0, "Bob should have outcome1 shares");

        uint256 bobBalBefore = bob.balance;
        market.claimVoidedOutcomeShares(marketId, 1);
        uint256 bobBalAfter = bob.balance;

        // He should get back a portion of the pool for those shares
        // Hard to do exact math here, so let's just confirm bobBalAfter > bobBalBefore
        assertTrue(bobBalAfter > bobBalBefore, "Bob didn't receive any voided share payout");
        vm.stopPrank();
    }

    // 8) ClaimLiquidity after resolved
    function testClaimLiquidity() public {
        uint256 marketId = createTestMarket(alice, 2 ether, 2);

        // Make some trades so fees accumulate
        vm.startPrank(bob);
        market.buy{value: 0.5 ether}(marketId, 0, 1);
        vm.stopPrank();

        // skip to close
        skip(3);

        // Resolve outcome 0
        vm.prank(alice);
        market.manualResolveMarketOutcome(marketId, 0);

        // Now Alice claims liquidity
        vm.startPrank(alice);
        (uint256 aliceLp, , ) = market.getUserMarketShares(marketId, alice);
        assertTrue(aliceLp > 0, "Alice has no liquidity shares");

        uint256 aliceBalBefore = alice.balance;
        market.claimLiquidity(marketId);
        uint256 aliceBalAfter = alice.balance;
        assertTrue(aliceBalAfter > aliceBalBefore, "Alice didn't receive liquidity claim");
        vm.stopPrank();
    }

    // 9) Claim Fees
    function testClaimFees() public {
        // Create a market, do some trades, see if liquidity provider can claim fees
        uint256 marketId = createTestMarket(alice, 2 ether, 1 days);

        // Bob makes a buy trade => fees accumulate
        vm.prank(bob);
        market.buy{value: 1 ether}(marketId, 0, 1);

        // Before claiming, let's see how much Alice can claim
        uint256 claimableBefore = market.getUserClaimableFees(marketId, alice);
        assertTrue(claimableBefore > 0, "Alice should have some claimable fees after Bob's trade");

        vm.prank(alice);
        market.claimFees(marketId);

        // Now should be zero
        uint256 claimableAfter = market.getUserClaimableFees(marketId, alice);
        assertEq(claimableAfter, 0, "Fees should have been claimed");
    }

    // Check revert if user tries to buy or sell with no liquidity
    function testBuyFailsOnZeroPool() public {
        // Edge scenario: create market with 0 stake? It's disallowed by the code, but let's do a test anyway

        // We'll do a direct approach:
        vm.startPrank(alice);

        vm.expectRevert("Initial stake must be > 0");
        market.createMarket{value: 0}(
            "Test?",
            "img",
            block.timestamp + 1 days,
            address(0x111),
            2
        );
        vm.stopPrank();
    }



    function testFullFlowScenario() public {
        // -------------------------
        // 1) ALICE CREATES MARKET
        // -------------------------
        // We'll say the closing time is short, e.g., 2 seconds from now
        uint256 closesInSec = 2;
        uint256 initialStake = 2 ether;
    
    
        vm.startPrank(alice);
        uint256 marketId = market.createMarket{value: initialStake}(
            "Full Flow Market - Will the special event happen?",
            "ipfs://some_image",
            block.timestamp + closesInSec,
            address(1234), // arbitrator placeholder
            2 // binary
        );
        vm.stopPrank();
    
        // -------------------------
        // 2) BOB & CAROL BUY OUTCOMES
        // -------------------------

    
        // Bob buys outcome 0 for 1 ETH
        vm.startPrank(bob);
        market.buy{value: 20 ether}(marketId, 0, 1); 
        vm.stopPrank();
    
        // Carol buys outcome 1 for 0.5 ETH
        vm.startPrank(carol);
        market.buy{value: 25 ether}(marketId, 1, 1);
        vm.stopPrank();
    
        // -------------------------
        // 3) DAVE ADDS LIQUIDITY
        // -------------------------
        // Dave wasn't the one who created, but he can still provide liquidity
        address dave = makeAddr("dave");
        vm.deal(dave, 90 ether);
    
        vm.startPrank(dave);
        market.addLiquidity{value: 1 ether}(marketId); // Dave adds 1 ETH to liquidity
        vm.stopPrank();
    
        // Let's record everyone's ETH balances before resolution (for reference)
        uint256 bobBalBeforeResolve = bob.balance;
        uint256 carolBalBeforeResolve = carol.balance;
        uint256 daveBalBeforeResolve = dave.balance;
        uint256 aliceBalBeforeResolve = alice.balance; 
    
        // -------------------------
        // 4) ADVANCE TIME & RESOLVE
        // -------------------------
        // skip so block.timestamp > closesAt
        skip(closesInSec + 1);
    
        // Trigger timeTransitions to transition the market to 'closed' state
        // We use getMarketData as it includes the timeTransitions modifier
        market.getMarketData(marketId);
    
        // Now "manualResolveMarketOutcome" => closed -> resolved
        // Suppose outcome 0 is the winner, and Dave is heavily providing liquidity for outcome 0 
        // (or we can just pick 0 if we want Dave to have advantage)
        vm.prank(alice);
        market.manualResolveMarketOutcome(marketId, 0);
    
        // -------------------------
        // 5) EVERYONE CLAIMS
        // -------------------------
    
        // Bob had outcome0 shares => he should get winnings 
        // Dave is also effectively "supporting" outcome0 with liquidity 
        // Alice as the market creator also had some liquidity from creation
        // Carol had outcome1 => that is losing => gets 0
        // but Carol can still claim fees if she provided liquidity (didn't in this scenario though)
        
        // BOB: claims his winnings from outcome0
        vm.startPrank(bob);
        uint256 bobBalBefore = bob.balance;
        market.claimWinnings(marketId); 
        uint256 bobBalAfter = bob.balance;
        vm.stopPrank();
    
        // CAROL: had outcome1, so no direct "winnings" => let's see if she tries to claim (should revert or 0)
        // We'll just skip her claimWinnings because outcome1 is losing
    
        // DAVE: first claim any fees if relevant, then claim his liquidity
        vm.startPrank(dave);
        market.claimFees(marketId); // might or might not pay out
        uint256 daveBalBefore = dave.balance;
        market.claimLiquidity(marketId);
        uint256 daveBalAfter = dave.balance;
        vm.stopPrank();
    
        // ALICE: She also had liquidity from creation
        vm.startPrank(alice);
        // claim fees first if any
        market.claimFees(marketId);
        // then claim liquidity
        uint256 aliceBalBefore = alice.balance;
        market.claimLiquidity(marketId);
        uint256 aliceBalAfter = alice.balance;
        vm.stopPrank();
    
        // -------------------------
        // 6) CHECK FINAL BALANCES
        // -------------------------
        
        // BOB => got some +ETH from winning outcome
        // So bobBalAfter - bobBalBefore > 0
        assertTrue((bobBalAfter - bobBalBefore) > 0, "Bob didn't gain from winning outcome");
    
        // CAROL => no call to claim => didn't have winning shares => final balance ~ her old balance
        // We can just verify she didn't get big changes if we want
        assertApproxEqAbs(carol.balance, carolBalBeforeResolve, 1e14, "Carol changed unexpectedly");
    
        // DAVE => as an LP for outcome 0, likely gained from pool / fees
        // So we expect daveBalAfter > daveBalBefore, but let's do approximate
        assertTrue(daveBalAfter > daveBalBefore, "Dave did not gain from liquidity claim");
    
        // ALICE => also an LP from creation => should have gained some
        // or at least see if her final is > aliceBalBeforeResolve
        assertTrue(aliceBalAfter >= aliceBalBefore, "Alice gained no liquidity share?");
    
        // Check final pool balance = 0 => means everything is fully claimed
        // If the contract is a standard (non-upgradeable) contract, you can do:
        uint256 finalPoolBal = address(market).balance;
        assertApproxEqAbs(finalPoolBal, 0,1e14, "Market contract still holds ETH after all claims!");
    
        // Optional: Log results for debugging
        emit log_named_uint("Bob's final balance", bob.balance);
        emit log_named_uint("Carol's final balance", carol.balance);
        emit log_named_uint("Dave's final balance", dave.balance);
        emit log_named_uint("Alice's final balance", alice.balance);
        emit log_named_uint("Contract final balance", finalPoolBal);
    }
    
}
