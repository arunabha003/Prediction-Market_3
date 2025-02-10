// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../contracts/errors/MarketErrors.sol";

import {IMarketAMM} from "../contracts/interfaces/IMarketAMM.sol";

import {MarketAMM} from "../contracts/MarketAMM.sol";

contract MarketAMMTest is Test {
    using Math for uint256;

    IMarketAMM marketAMM;

    function setUp() external {
        marketAMM = new MarketAMM();
    }

    /*//////////////////////////////////////////////////////////////
                            getAddLiquidityData
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Test the getAddLiquidityData function when the liquidity is zero
     *         The liquidity shares minted to the user should be equal to the amount added
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be equal to the amount added
     */
    function test_getAddLiquidityData_when_zero_liquidity() external view {
        // Arrange
        uint256 amount = 100 ether;

        // Act
        (uint256 liquidityShares, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) =
        marketAMM.getAddLiquidityData(
            amount, IMarketAMM.MarketPoolState({liquidity: 0, outcomeShares: new uint256[](2)})
        );

        // Assert
        assertEq(liquidityShares, amount);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(newOutcomesShares[0], amount);
        assertEq(newOutcomesShares[1], amount);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), liquidityShares, 1e6);
    }

    /**
     * @notice Test the getAddLiquidityData function when the price is equal and there is liquidity in the pool
     *         The liquidity shares minted to the user should be equal to the amount added
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be equal to the amount added
     * @dev To make the price equal, the outcome shares should be equal (outcomeA * outcomeB = liquidity ^ 2)
     */
    function test_getAddLiquidityData_when_price_is_equal() external view {
        // Arrange
        uint256 amount = 100 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 50 ether;
        outcomeShares[1] = 50 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 liquidityShares, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) =
        marketAMM.getAddLiquidityData(
            amount, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity + liquidityShares;
        assertEq(liquidityShares, amount);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(newOutcomesShares[0], 150 ether);
        assertEq(newOutcomesShares[1], 150 ether);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    /**
     * @notice Test the getAddLiquidityData function when the price is NOT equal and there is liquidity in the pool
     *         The liquidity shares minted to the user should be less than the amount added
     *         The outcome shares to give back to the user should be from the most likely outcome
     * @dev    The most likely outcome is the one with the lowest outcome shares
     */
    function test_getAddLiquidityData_when_price_is_NOT_equal() external view {
        // Arrange
        uint256 amount = 1000 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 861.17 ether;
        outcomeShares[1] = 1405.07 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 liquidityShares, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) =
        marketAMM.getAddLiquidityData(
            amount, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertApproxEqAbs(liquidityShares, 782.87 ether, 1 ether); // the 782.87 is the rounded expected value

        assertApproxEqAbs(outcomeSharesToReturn[0], 387.09 ether, 1 ether); // 387.09 is the rounded expected value
        assertEq(outcomeSharesToReturn[1], 0);

        assertApproxEqAbs(newOutcomesShares[0], 1474.07 ether, 1 ether); // most likely outcome is increased by the amount and reduced
        assertEq(newOutcomesShares[1], outcomeShares[1] + amount); // less likely outcome is increased by the amount
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), liquidity + liquidityShares, 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                            getRemoveLiquidityData
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Test the getRemoveLiquidityData function when the reserves are equal
     *         The liquidity value in ETH should be equal to the liquidity shares to remove
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be reduced by the liquidity shares
     */
    function test_getRemoveLiquidityData_when_price_is_equal() external view {
        // Arrange
        uint256 liquidityShares = 400 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 3000 ether;
        outcomeShares[1] = 3000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - amount;
        assertEq(newLiquidity, 2600 ether);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(newOutcomesShares[0], 2600 ether);
        assertEq(newOutcomesShares[1], 2600 ether);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    function test_fuzz_getRemoveLiquidityData_when_price_is_equal(uint256 liquidityShares, uint256 outcomeAmount)
        external
        view
    {
        // Arrange
        outcomeAmount = bound(outcomeAmount, 1, 99999999999999999999 ether);
        liquidityShares = bound(liquidityShares, 0, outcomeAmount);

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = outcomeAmount;
        outcomeShares[1] = outcomeAmount;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - amount;
        assertEq(newLiquidity, outcomeAmount - liquidityShares);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(newOutcomesShares[0], outcomeAmount - liquidityShares);
        assertEq(newOutcomesShares[1], outcomeAmount - liquidityShares);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    /**
     * @notice Test the getRemoveLiquidityData function when the last liquidity provider exits and the price is equal
     *         The liquidity value in ETH should be equal to the liquidity shares to remove
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be 0
     */
    function test_getRemoveLiquidityData_when_last_liquidity_provider_price_is_equal() external view {
        // Arrange
        uint256 liquidityShares = 1000 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - amount;
        assertEq(newLiquidity, 0);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(newOutcomesShares[0], 0);
        assertEq(newOutcomesShares[1], 0);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    /**
     * @notice Test the getRemoveLiquidityData function when the price is NOT equal
     *         The liquidity value in ETH should be less than the liquidity shares to remove
     *         The outcome shares to give back should be from the less likely outcome
     * @dev    The most likely outcome is the one with the lowest outcome shares
     */
    function test_getRemoveLiquidityData_when_price_is_NOT_equal() external view {
        // Arrange
        uint256 liquidityShares = 500 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1406.25 ether;
        outcomeShares[1] = 1600 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - liquidityShares;
        assertApproxEqAbs(amount, 468.75 ether, 0.01 ether);
        assertApproxEqAbs(newLiquidity, 1000 ether, 0.01 ether);
        assertEq(outcomeSharesToReturn[0], 0);
        assertApproxEqAbs(outcomeSharesToReturn[1], 64.583 ether, 0.01 ether);
        assertApproxEqAbs(newOutcomesShares[0], 937.5 ether, 0.01 ether);
        assertApproxEqAbs(newOutcomesShares[1], 1066.66 ether, 0.01 ether);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    function test_fuzz_getRemoveLiquidityData_when_price_is_NOT_equal(
        uint256 liquidityShares,
        uint256 outcomeAShares,
        uint256 outcomeBShares
    ) external view {
        // Arrange
        outcomeAShares = bound(outcomeAShares, 1, 999999999999999999 ether);
        outcomeBShares = bound(outcomeBShares, 1, 999999999999999999 ether);

        vm.assume(outcomeAShares != outcomeBShares);

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = outcomeAShares;
        outcomeShares[1] = outcomeBShares;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        liquidityShares = bound(liquidityShares, 0, liquidity);

        // Act
        (uint256 liquidityValue, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 lessLikeOutcomeIndex = outcomeAShares < outcomeBShares ? 1 : 0;
        uint256 newLiquidity = liquidity - liquidityShares;
        assertGe(liquidityValue, 0);
        assertGe(outcomeSharesToReturn[lessLikeOutcomeIndex], 0);
        assertGe(newOutcomesShares[0], 0);
        assertGe(newOutcomesShares[1], 0);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1 ether);
    }

    function test_getRemoveLiquidityData_when_last_liquidity_provider() external view {
        // Arrange
        uint256 liquidityShares = 800 ether;
        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 400 ether;
        outcomeShares[1] = 1600 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - liquidityShares;
        assertEq(amount, 400 ether);
        assertEq(newLiquidity, 0);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 1200 ether);
        assertEq(newOutcomesShares[0], 0);
        assertEq(newOutcomesShares[1], 0);
        assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), newLiquidity, 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                            getBuyOutcomeData
    //////////////////////////////////////////////////////////////*/
    function test_getBuyOutcomeData_correctly_calculates_shares() external view {
        // Arrange
        uint256 amount = 294 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 shares) = marketAMM.getBuyOutcomeData(
            amount, outcomeIndex, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertApproxEqAbs(shares, 521.2024 ether, 0.0001 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            getSellOutcomeData
    //////////////////////////////////////////////////////////////*/
    function test_getSellOutcomeData_correctly_calculates_shares() external view {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 909.09 ether;
        outcomeShares[1] = 1100 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 shares) = marketAMM.getSellOutcomeData(
            amount, outcomeIndex, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertApproxEqAbs(shares, 190.909 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_correctly_calculates_shares_balanced() external view {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 shares) = marketAMM.getSellOutcomeData(
            amount, outcomeIndex, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertApproxEqAbs(shares, 211.1111 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_correctly_calculates_large_amount() external view {
        // Arrange
        uint256 amount = 10000 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 90.90909 ether;
        outcomeShares[1] = 11000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 shares) = marketAMM.getSellOutcomeData(
            amount, outcomeIndex, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertApproxEqAbs(shares, 10909.0909 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_reverts_on_insufficient_liquidity() external {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 100 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act & Assert
        vm.expectRevert(InsufficientLiquidity.selector);
        marketAMM.getSellOutcomeData(
            amount, outcomeIndex, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );
    }

    /*//////////////////////////////////////////////////////////////
                            getClaimLiquidityData
    //////////////////////////////////////////////////////////////*/
    function test_getClaimLiquidityData_correctly_calculates_amount() external view {
        // Arrange
        uint256 liquidityShares = 300 ether;
        uint256 resolvedOutcomeShares = 500 ether;
        uint256 liquidity = 1000 ether;

        // Act
        (uint256 amount) = marketAMM.getClaimLiquidityData(liquidityShares, resolvedOutcomeShares, liquidity);

        // Assert
        assertEq(amount, 150 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            getOutcomePrice
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The formula for price calculation is PriceA = outcomeSharesB / (outcomeSharesA + outcomeSharesB)
     * @dev    The formula for price calculation is desiredOutcomePrice = oppositeOutcomeShares / (desiredOutcomeShares + oppositeOutcomeShares)
     */
    function test_getOutcomePrice_correctly_calculates_price() external view {
        // Arrange
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 price) = marketAMM.getOutcomePrice(
            outcomeIndex,
            outcomeShares[0] + outcomeShares[1],
            IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertEq(price, 0.5 ether);
    }

    function test_getOutcomePrice_correctly_calculates_price_unbalanced() external view {
        // Arrange
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = 400 ether;
        outcomeShares[1] = 600 ether;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 price) = marketAMM.getOutcomePrice(
            outcomeIndex,
            outcomeShares[0] + outcomeShares[1],
            IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertEq(price, 0.6 ether);
    }

    function test_fuzz_getOutcomePrice(uint256 outcomeAShares, uint256 outcomeBShares) external view {
        // Arrange
        outcomeAShares = bound(outcomeAShares, 1, 999999999999999999 ether);
        outcomeBShares = bound(outcomeBShares, 1, 999999999999999999 ether);

        vm.assume(outcomeAShares != outcomeBShares);

        uint256[] memory outcomeShares = new uint256[](2);
        outcomeShares[0] = outcomeAShares;
        outcomeShares[1] = outcomeBShares;
        uint256 liquidity = Math.sqrt(outcomeShares[0] * outcomeShares[1]);

        // Act
        (uint256 priceA) = marketAMM.getOutcomePrice(
            0,
            outcomeAShares + outcomeBShares,
            IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );
        (uint256 priceB) = marketAMM.getOutcomePrice(
            1,
            outcomeAShares + outcomeBShares,
            IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        assertGe(priceA, 0);
        assertLe(priceA, 1 ether);
        assertGe(priceB, 0);
        assertLe(priceB, 1 ether);
        assertApproxEqAbs(priceA + priceB, 1 ether, 1e1);
    }
}
