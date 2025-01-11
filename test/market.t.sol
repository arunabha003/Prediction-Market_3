// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import  {Test, console} from  "forge-std/Test.sol";
import {PolymarketFactory} from "../src/MarketFactory.sol";
import {PolymarketMarket } from "../src/Market.sol";
import {PolymarketAMM } from "../src/MarketAMM.sol";

// ============ Mock USDC ============

contract MockUSDC is Test {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient bal");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient bal");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

// ============ Full-Flow Test ============

contract PolymarketFlowTest is Test {
    // Users
    address deployer = makeAddr("deployer");
    address owner    = makeAddr("owner");
    address oracle   = makeAddr("oracle");
    address alice    = makeAddr("alice");
    address bob      = makeAddr("bob");
    address arun     =makeAddr("arun");
    address luv      =makeAddr("luv");
    address jimmy    =makeAddr("jimmy");

    // Contracts
    MockUSDC mockUSDC;
    PolymarketFactory factory;
    PolymarketMarket market;
    PolymarketAMM amm;

    // Market info
    string question = "Will Team A win the championship?";
    uint256 closeTime; 
    uint256 feeBps = 100; // 1% fee

    // Set up Foundry test environment
    function setUp() public {
        vm.startPrank(deployer);
        console.log(deployer);

        // 1) Deploy our mock USDC
        mockUSDC = new MockUSDC();

        // 2) Deploy the factory
        factory = new PolymarketFactory();
        factory.initialize(); // calls initializer for UUPS + Ownable
        factory.transferOwnership(owner);

        vm.stopPrank();

        // set closeTime to 2 days from now
        closeTime = block.timestamp + 2 days;
        
        // Give Alice and Bob some USDC
        vm.startPrank(deployer);
        mockUSDC.mint(alice, 10_000e6);
        mockUSDC.mint(bob,   10_000e6);
        mockUSDC.mint(arun,   10_000e6);
        mockUSDC.mint(luv,   10_000e6);
        mockUSDC.mint(jimmy,  10_000e6);

        vm.stopPrank();



    }

    function testFullFlow() public {
        // Step 1: Owner calls factory to create market
        vm.startPrank(owner);

        // We create the market
        // params: createMarket(usdc, uri, questions, closeTime, oracle, feeBps)
        (address _marketAddr, address _ammAddr) = factory.createMarket(
            address(mockUSDC),
            "ipfs://dummy-uri/",
            question,
            closeTime,
            oracle,
            feeBps
        );

        // Typecast
        market = PolymarketMarket(_marketAddr);
        amm    = PolymarketAMM(_ammAddr);

        vm.stopPrank();

        vm.prank(_ammAddr);

        // approve Market to transfer USDC from AMM
        mockUSDC.approve(_marketAddr, type(uint256).max);

        // Step 2: Alice adds liquidity
        vm.startPrank(alice);

        // 2a) Approve AMM to spend Alice's USDC
        mockUSDC.approve(_ammAddr, 5_000e6);

        console.log("Alice USDC balance before provifing liqudity", mockUSDC.balanceOf(alice));
        // 2b) add liquidity
        amm.addLiquidity(5_000e6);

        // check some basic invariants
        // after first add, totalLPSupply == 5000e6
        assertEq(amm.totalLPSupply(), 5_000e6, "LP supply mismatch");
        // The market's LP token ID=2 balanceOf(alice) should be 5000e6
        uint256 aliceLPBal = market.balanceOf(alice, 2);
        assertEq(aliceLPBal, 5_000e6, "Alice should hold 5k LP");

        vm.stopPrank();

        // Step 3: Bob buys YES shares (ID=0)
        vm.startPrank(bob);

        // 3a) Approve
        mockUSDC.approve(_ammAddr, 2_000e6);

        // 3b) buy YES
        amm.buyShares(market.YES_TOKEN_ID(), 2_000e6);

        // check Bob's YES balance
        uint256 bobYesBal = market.balanceOf(bob, 0);
        assertGt(bobYesBal, 0, "Bob must get some YES shares");

        vm.stopPrank();

        // fast-forward to after closeTime
        vm.warp(closeTime + 1);

        // Step 4: Oracle resolves the market (let's say YES wins)
        vm.startPrank(oracle);
        market.resolveMarket(market.YES_TOKEN_ID());
        vm.stopPrank();

        // Step 5: Bob redeems his winning shares
        vm.startPrank(bob);

        uint256 bobYesBalanceBefore = market.balanceOf(bob, 0);
        // Should redeem 1 USDC per YES share
        // check Bob's USDC before
        uint256 bobUSDCBefore = mockUSDC.balanceOf(bob);

        console.log("USDC balance of AMM ", mockUSDC.balanceOf(_ammAddr));



        // redeem
        market.redeemWinnings(market.YES_TOKEN_ID(), bobYesBalanceBefore);

        // check Bob's USDC after
        uint256 bobUSDCAfter = mockUSDC.balanceOf(bob);
        assertEq(
            bobUSDCAfter,
            bobUSDCBefore + bobYesBalanceBefore,
            "Bob should gain 1 USDC per YES share"
        );

        // check Bob's new YES token balance
        uint256 bobYesAfter = market.balanceOf(bob, 0);
        assertEq(bobYesAfter, 0, "Bob's YES shares burned on redeem");

        vm.stopPrank();

        // Step 6: Alice (LP) can remove her liquidity
        vm.startPrank(alice);
        uint256 aliceLPBefore = market.balanceOf(alice, 2);
        // try removing 50% of her LP
        uint256 removeAmount = aliceLPBefore/2;

        uint256 aliceUSDCBefore = mockUSDC.balanceOf(alice);
        amm.removeLiquidity(removeAmount);

        // she should get some USDC out
        uint256 aliceUSDCAfter = mockUSDC.balanceOf(alice);
        assertGt(aliceUSDCAfter, aliceUSDCBefore, "Alice gets some USDC back");

        // her LP token balance should be lower
        uint256 aliceLPAfter = market.balanceOf(alice, 2);
        assertEq(aliceLPAfter, aliceLPBefore - removeAmount, "Half LP burned");

        //takes out the remaining LP
        amm.removeLiquidity(removeAmount);
        uint256 aliceUSDCFinal = mockUSDC.balanceOf(alice);

        console.log("Alice USDC balance after removing all LP", aliceUSDCFinal);
        console.log("AMM USDC balance after removing all LP", mockUSDC.balanceOf(_ammAddr));

        vm.stopPrank();

    }


    function testWithMultipleUsers() public {

        vm.startPrank(owner);

        // We create the market
        // params: createMarket(usdc, uri, questions, closeTime, oracle, feeBps)
        (address _marketAddr, address _ammAddr) = factory.createMarket(
            address(mockUSDC),
            "ipfs://dummy-uri/",
            question,
            closeTime,
            oracle,
            feeBps
        );

        // Typecast
        market = PolymarketMarket(_marketAddr);
        amm    = PolymarketAMM(_ammAddr);

        vm.stopPrank();

        vm.prank(_ammAddr);

        // approve Market to transfer USDC from AMM
        mockUSDC.approve(_marketAddr, type(uint256).max);




       // --------Multiple LPs--------//

        //arun adds liqudity of 5000 USDC
        vm.startPrank(arun);
        mockUSDC.approve(_ammAddr, 5_000e6);
        amm.addLiquidity(5_000e6);
        vm.stopPrank();

        //luv adds liqudity of 3000 USDC
        vm.startPrank(luv);
        mockUSDC.approve(_ammAddr, 3_000e6);
        amm.addLiquidity(3_000e6);
        vm.stopPrank();

        //Check total liqudity balance 
        uint256 ammUSDCBalance = mockUSDC.balanceOf(_ammAddr);
        assertEq(ammUSDCBalance, 8000e6, "Total Liqudity balance should be 8000 USDC");
        console.log("USDC total balance before any betting ", ammUSDCBalance);


        //------console the token shares-------//

        console.log(" Initally total YES token share: ", amm.reserveYes());
        console.log(" Initially total NO token share : ", amm.reserveNo());

        //----------Multiple user buying YES or NO shares--------//

        vm.startPrank(bob);
        mockUSDC.approve(_ammAddr, 2_000e6);
        amm.buyShares(market.YES_TOKEN_ID(), 2_000e6);
        console.log("Bob's YES token share :", market.balanceOf(bob, 0));
        console.log("USDC balance after Bob's betting ", mockUSDC.balanceOf(bob));
        vm.stopPrank();

        console.log(" total YES token share after Bob's bet: ", amm.reserveYes());
        console.log(" Initially total NO token share after Bob's bet : ", amm.reserveNo());



        vm.startPrank(alice);
        mockUSDC.approve(_ammAddr, 3_000e6);
        amm.buyShares(market.NO_TOKEN_ID(), 3_000e6);
        console.log("Alice's NO token share :", market.balanceOf(alice, 1));
        console.log("USDC balance after Alice's betting ", mockUSDC.balanceOf(alice));
        vm.stopPrank();

        console.log(" total YES token share after Alice's bet: ", amm.reserveYes());
        console.log(" Initially total NO token share after Alice's bet : ", amm.reserveNo());

        
        vm.startPrank(jimmy);
        mockUSDC.approve(_ammAddr, 1_00e6);
        amm.buyShares(market.YES_TOKEN_ID(), 1_00e6);
        console.log("Jimmy's YES token share :", market.balanceOf(jimmy, 0));
        console.log("USDC balance after Jimmy's betting ", mockUSDC.balanceOf(jimmy));
        vm.stopPrank();



        console.log(" total YES token share after Jimmy's bet: ", amm.reserveYes());
        console.log(" Initially total NO token share after Jimmy's bet : ", amm.reserveNo());

        console.log("USDC balance after all betting ", mockUSDC.balanceOf(_ammAddr));
        // fast-forward to after closeTime
        vm.warp(closeTime + 1);

        // Oracle resolves the market (let's say YES wins)
        vm.startPrank(oracle);
        market.resolveMarket(market.YES_TOKEN_ID());
        vm.stopPrank();


        //----------Multiple user redeeming their winning shares--------//

        vm.startPrank(bob);
        uint256 bobYesBalanceBefore = market.balanceOf(bob, 0);
        uint256 bobUSDCBefore = mockUSDC.balanceOf(bob);
        market.redeemWinnings(market.YES_TOKEN_ID(), bobYesBalanceBefore);

        uint256 bobUSDCAfter = mockUSDC.balanceOf(bob);
        assertEq(
            bobUSDCAfter,
            bobUSDCBefore + bobYesBalanceBefore,
            "Bob should gain 1 USDC per YES share"
        );

        uint256 bobYesAfter = market.balanceOf(bob, 0);
        assertEq(bobYesAfter, 0, "Bob's YES shares burned on redeem");

        vm.stopPrank();


        vm.startPrank(jimmy);
        uint256 jimmyYesBalanceBefore = market.balanceOf(jimmy, 0);
        uint256 jimmyUSDCBefore = mockUSDC.balanceOf(jimmy);
        market.redeemWinnings(market.YES_TOKEN_ID(), jimmyYesBalanceBefore);

        uint256 jimmyUSDCAfter = mockUSDC.balanceOf(jimmy);
        assertEq(
            jimmyUSDCAfter,
            jimmyUSDCBefore + jimmyYesBalanceBefore,
            "Bob should gain 1 USDC per YES share"
        );

        uint256 jimmyYesAfter = market.balanceOf(jimmy, 0);
        assertEq(jimmyYesAfter, 0, "Bob's YES shares burned on redeem");

        vm.stopPrank();

        console.log("USDC balance after all redeeming ", mockUSDC.balanceOf(_ammAddr));



        //-----Final betters profit and loss-----//

        console.log("Bob's USDC balance after all transactions", mockUSDC.balanceOf(bob));
        console.log("Alice's USDC balance after all transactions", mockUSDC.balanceOf(alice));
        console.log("Jimmy's USDC balance after all transactions", mockUSDC.balanceOf(jimmy));

        //----------Multiple user removing their liqudity--------//

        vm.startPrank(arun);
        uint256 arunLPBefore = market.balanceOf(arun, 2);
        uint256 removeAmount = arunLPBefore;
        uint256 arunUSDCBefore = mockUSDC.balanceOf(arun);
        amm.removeLiquidity(removeAmount);

        uint256 arunUSDCAfter = mockUSDC.balanceOf(arun);
        assertGt(arunUSDCAfter, arunUSDCBefore, "Arun gets some USDC back");

        console.log("Final USDC balance of Arun", mockUSDC.balanceOf(arun));

        uint256 arunLPAfter = market.balanceOf(arun, 2);
        assertEq(arunLPAfter, arunLPBefore - removeAmount, "All LP burned");

        vm.stopPrank();

        vm.startPrank(luv);
        uint256 luvLPBefore = market.balanceOf(luv, 2);
        removeAmount = luvLPBefore;
        uint256 luvUSDCBefore = mockUSDC.balanceOf(luv);
        amm.removeLiquidity(removeAmount);

        uint256 luvUSDCAfter = mockUSDC.balanceOf(luv);
        assertGt(luvUSDCAfter, luvUSDCBefore, "Luv gets some USDC back");
        
        console.log("Final USDC balance of Luv", mockUSDC.balanceOf(luv));

        uint256 luvLPAfter = market.balanceOf(luv, 2);
        assertEq(luvLPAfter, luvLPBefore - removeAmount, "All LP burned");


        console.log("USDC balance of AMM after all liqudity removal", mockUSDC.balanceOf(_ammAddr));
        vm.stopPrank();





        // console.log("Bob's profit after all the transactions", mockUSDC.balanceOf(bob) - 10000e6);
        // console.log("Alice's profit after all the transactions", mockUSDC.balanceOf(alice) - 10000e6);
        // console.log("Jimmy's profit after all the transactions", mockUSDC.balanceOf(jimmy) - 10000e6);

        


    }




    function testLPinUnevenMarket() public {

        vm.startPrank(owner);

        // We create the market
        // params: createMarket(usdc, uri, questions, closeTime, oracle, feeBps)
        (address _marketAddr, address _ammAddr) = factory.createMarket(
            address(mockUSDC),
            "ipfs://dummy-uri/",
            question,
            closeTime,
            oracle,
            feeBps
        );

        // Typecast
        market = PolymarketMarket(_marketAddr);
        amm    = PolymarketAMM(_ammAddr);

        vm.stopPrank();

        vm.prank(_ammAddr);

        // approve Market to transfer USDC from AMM
        mockUSDC.approve(_marketAddr, type(uint256).max);


       // --------Initial LP--------//

        //arun adds liqudity of 5000 USDC
        vm.startPrank(arun);
        mockUSDC.approve(_ammAddr, 9_000e6);
        amm.addLiquidity(9_000e6);
        vm.stopPrank();


        //Check total liqudity balance 
        uint256 ammUSDCBalance = mockUSDC.balanceOf(_ammAddr);
        assertEq(ammUSDCBalance, 9000e6, "Total Liqudity balance should be 8000 USDC");
        console.log("USDC total balance before any betting ", ammUSDCBalance);


        //----------Multiple user buying YES or NO shares--------//

        vm.startPrank(bob);
        mockUSDC.approve(_ammAddr, 1_000e6);
        amm.buyShares(market.YES_TOKEN_ID(), 1_000e6);
        console.log("Bob's YES token share :", market.balanceOf(bob, 0));
        console.log("USDC balance after Bob's betting ", mockUSDC.balanceOf(bob));
        vm.stopPrank();

        vm.startPrank(alice);
        mockUSDC.approve(_ammAddr, 1_000e6);
        amm.buyShares(market.YES_TOKEN_ID(), 1_000e6);
        console.log("Alice's NO token share :", market.balanceOf(alice, 0));
        console.log("USDC balance after Alice's betting ", mockUSDC.balanceOf(alice));
        vm.stopPrank();

        //------console market proabilities-------//

        (uint256 yes, uint256 no) = amm.returnProbabilities();
        console.log("Probabilities before uneven LP",yes, no);

        //--------------------Adding more LPs-------------------//

        vm.startPrank(luv);
        mockUSDC.approve(_ammAddr, 3_000e6);
        amm.addLiquidity(3_000e6);
        vm.stopPrank();


        (uint256 yesAfter, uint256 noAfter) = amm.returnProbabilities();
        console.log("Probabilities before uneven LP",yesAfter, noAfter);
        //--------------------More user buying share-------------------//

        vm.startPrank(jimmy);
        mockUSDC.approve(_ammAddr, 1_000e6);
        amm.buyShares(market.NO_TOKEN_ID(), 1_000e6);
        console.log("Jimmy's YES token share :", market.balanceOf(jimmy, 1));
        console.log("USDC balance after Jimmy's betting ", mockUSDC.balanceOf(jimmy));
        vm.stopPrank();


        console.log("USDC balance after all betting ", mockUSDC.balanceOf(_ammAddr));
        // fast-forward to after closeTime
        vm.warp(closeTime + 1);

        // Oracle resolves the market (let's say YES wins)
        vm.startPrank(oracle);
        market.resolveMarket(market.YES_TOKEN_ID());
        vm.stopPrank();


        //----------Multiple user redeeming their winning shares--------//

        vm.startPrank(bob);
        uint256 bobYesBalanceBefore = market.balanceOf(bob, 0);
        uint256 bobUSDCBefore = mockUSDC.balanceOf(bob);
        market.redeemWinnings(market.YES_TOKEN_ID(), bobYesBalanceBefore);

        uint256 bobUSDCAfter = mockUSDC.balanceOf(bob);
        assertEq(
            bobUSDCAfter,
            bobUSDCBefore + bobYesBalanceBefore,
            "Bob should gain 1 USDC per YES share"
        );

        uint256 bobYesAfter = market.balanceOf(bob, 0);
        assertEq(bobYesAfter, 0, "Bob's YES shares burned on redeem");

        vm.stopPrank();


        // vm.startPrank(jimmy);
        // uint256 jimmyYesBalanceBefore = market.balanceOf(jimmy, 1);
        // uint256 jimmyUSDCBefore = mockUSDC.balanceOf(jimmy);
        // market.redeemWinnings(market.NO_TOKEN_ID(), jimmyYesBalanceBefore);

        // uint256 jimmyUSDCAfter = mockUSDC.balanceOf(jimmy);
        // assertEq(
        //     jimmyUSDCAfter,
        //     jimmyUSDCBefore + jimmyYesBalanceBefore,
        //     "Bob should gain 1 USDC per YES share"
        // );

        // uint256 jimmyYesAfter = market.balanceOf(jimmy, 1);
        // assertEq(jimmyYesAfter, 0, "Bob's YES shares burned on redeem");

        // vm.stopPrank();

        // console.log("USDC balance after all redeeming ", mockUSDC.balanceOf(_ammAddr));


        vm.startPrank(alice);
        uint256 aliceYesBalanceBefore = market.balanceOf(alice, 0);
        uint256 aliceUSDCBefore = mockUSDC.balanceOf(alice);
        market.redeemWinnings(market.YES_TOKEN_ID(), aliceYesBalanceBefore);

        uint256 aliceUSDCAfter = mockUSDC.balanceOf(alice);
        assertEq(
            aliceUSDCAfter,
            aliceUSDCBefore + aliceYesBalanceBefore,
            "Bob should gain 1 USDC per YES share"
        );

        uint256 aliceYesAfter = market.balanceOf(alice, 0);
        assertEq(aliceYesAfter, 0, "Bob's YES shares burned on redeem");

        vm.stopPrank();

        console.log("USDC balance after all redeeming ", mockUSDC.balanceOf(_ammAddr));



        //-----Final betters profit and loss-----//

        console.log("Bob's USDC balance after all transactions", mockUSDC.balanceOf(bob));
        console.log("Alice's USDC balance after all transactions", mockUSDC.balanceOf(alice));
        console.log("Jimmy's USDC balance after all transactions", mockUSDC.balanceOf(jimmy));

        //----------Multiple user removing their liqudity--------//




        vm.startPrank(luv);

        uint256 luvLPBefore = market.balanceOf(luv, 2);
        uint256 removeAmount = luvLPBefore;
        uint256 luvUSDCBefores = mockUSDC.balanceOf(luv);
        amm.removeLiquidity(removeAmount);

        uint256 luvUSDCAfters = mockUSDC.balanceOf(luv);
        assertGt(luvUSDCAfters, luvUSDCBefores, "Luv gets some USDC back");
        


        uint256 luvLPAfter = market.balanceOf(luv, 2);
        assertEq(luvLPAfter, luvLPBefore - removeAmount, "All LP burned");
        console.log("Final USDC balance of Luv", mockUSDC.balanceOf(luv));
        vm.stopPrank();





        vm.startPrank(arun);
        uint256 arunLPBefore = market.balanceOf(arun, 2);
        removeAmount = arunLPBefore;
        uint256 arunUSDCBefore = mockUSDC.balanceOf(arun);
        amm.removeLiquidity(removeAmount);

        uint256 arunUSDCAfter = mockUSDC.balanceOf(arun);
        assertGt(arunUSDCAfter, arunUSDCBefore, "Arun gets some USDC back");

        console.log("Final USDC balance of Arun", mockUSDC.balanceOf(arun));

        uint256 arunLPAfter = market.balanceOf(arun, 2);
        assertEq(arunLPAfter, arunLPBefore - removeAmount, "All LP burned");

        vm.stopPrank();


        console.log("luv YES token balance", market.balanceOf(luv, 0));
        console.log("luv NO token balance", market.balanceOf(luv, 1));



        console.log("USDC balance of AMM after all liqudity removal", mockUSDC.balanceOf(_ammAddr));
        vm.stopPrank();


        //--------------------luv removes his winning tokens-------------------//

        // vm.startPrank(luv);
        // uint256 luvNOBalanceBefore = market.balanceOf(luv, 0);
        // uint256 luvUSDCBefore = mockUSDC.balanceOf(luv);
        // market.redeemWinnings(market.YES_TOKEN_ID(), luvNOBalanceBefore);

        // uint256 luvUSDCAfter = mockUSDC.balanceOf(luv);
        // assertEq(
        //     luvUSDCAfter,
        //     luvUSDCBefore + luvNOBalanceBefore,
        //     "Bob should gain 1 USDC per YES share"
        // );

        // uint256 luvNOAfter = market.balanceOf(luv, 0);
        // assertEq(luvNOAfter,0 , "Luv NO shares burned on redeem");
        // console.log("Final USDC balance of Luv", mockUSDC.balanceOf(luv));


    
    }



}
