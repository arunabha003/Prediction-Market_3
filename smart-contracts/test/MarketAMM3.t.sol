// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../contracts/errors/MarketErrors.sol";

import {IMarketAMM} from "../contracts/interfaces/IMarketAMM3.sol";

import {MarketAMM3} from "../contracts/MarketAMM3.sol";
import {MathUtils} from "./helpers/MathIUtils.sol";

contract MarketAMMTest is Test {
    using Math for uint256;

    IMarketAMM marketAMM;

    function setUp() external {
        marketAMM = new MarketAMM3();
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
    function test_getAddLiquidityData_when_zero_liquidity_V3() external view {
        // Arrange
        uint256 amount = 100 ether;

        // Act
        (
            uint256 liquidityShares,
            uint256[] memory outcomeSharesToReturn,
            uint256[] memory newOutcomesShares
        ) = marketAMM.getAddLiquidityData(
                amount,
                IMarketAMM.MarketPoolState({
                    liquidity: 0,
                    outcomeShares: new uint256[](3)
                })
            );

        // Assert
        assertEq(liquidityShares, amount);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(outcomeSharesToReturn[2], 0);

        assertEq(newOutcomesShares[0], amount);
        assertEq(newOutcomesShares[1], amount);
        assertEq(newOutcomesShares[2], amount);

        assertApproxEqAbs(
            MathUtils.cbrt(
                newOutcomesShares[0] *
                    newOutcomesShares[1] *
                    newOutcomesShares[2]
            ),
            liquidityShares,
            1e6
        );
    }

    /**
     * @notice Test the getAddLiquidityData function when the price is equal and there is liquidity in the pool
     *         The liquidity shares minted to the user should be equal to the amount added
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be equal to the amount added
     * @dev To make the price equal, the outcome shares should be equal (outcomeA * outcomeB = liquidity ^ 2)
     */
    function test_getAddLiquidityData_when_price_is_equal_V3() external view {
        // Arrange
        uint256 amount = 100 ether;
        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 50 ether;
        outcomeShares[1] = 50 ether;
        outcomeShares[2] = 50 ether;

        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        (
            uint256 liquidityShares,
            uint256[] memory outcomeSharesToReturn,
            uint256[] memory newOutcomesShares
        ) = marketAMM.getAddLiquidityData(
                amount,
                IMarketAMM.MarketPoolState({
                    liquidity: liquidity,
                    outcomeShares: outcomeShares
                })
            );

        // Assert
        uint256 newLiquidity = liquidity + liquidityShares;
        assertEq(liquidityShares, amount);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(outcomeSharesToReturn[2], 0);

        assertEq(newOutcomesShares[0], 150 ether);
        assertEq(newOutcomesShares[1], 150 ether);
        assertEq(newOutcomesShares[2], 150 ether);

        assertApproxEqAbs(
            MathUtils.cbrt(
                newOutcomesShares[0] *
                    newOutcomesShares[1] *
                    newOutcomesShares[2]
            ),
            newLiquidity,
            1e6
        );
    }

    /**
     * @notice Test the getAddLiquidityData function when the price is NOT equal and there is liquidity in the pool
     *         The liquidity shares minted to the user should be less than the amount added
     *         The outcome shares to give back to the user should be from the most likely outcome
     * @dev    The most likely outcome is the one with the lowest outcome shares
     */
    function test_getAddLiquidityData_when_price_is_NOT_equal_V3()
        external
        view
    {
        // Arrange
        uint256 amount = 100 ether;
        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 400 ether;
        outcomeShares[2] = 200 ether;
        // uint256 liquidity = MathUtils.cbrt(outcomeShares[0] * outcomeShares[1]* outcomeShares[2]);
        uint256 liquidity = 363.42 ether;

        // Act
        (
            uint256 liquidityShares,
            uint256[] memory outcomeSharesToReturn,
            uint256[] memory newOutcomesShares
        ) = marketAMM.getAddLiquidityData(
                amount,
                IMarketAMM.MarketPoolState({
                    liquidity: liquidity,
                    outcomeShares: outcomeShares
                })
            );

        // Assert
        assertApproxEqAbs(liquidityShares, 60.57 ether, 1 ether); // the 782.87 is the rounded expected value

        assertApproxEqAbs(outcomeSharesToReturn[2], 66.67 ether, 1 ether); //most likely
        assertApproxEqAbs(outcomeSharesToReturn[1], 33.33 ether, 1 ether); //mid likely
        assertEq(outcomeSharesToReturn[0], 0);

        assertApproxEqAbs(newOutcomesShares[2], 233.33 ether, 1 ether);
        assertApproxEqAbs(newOutcomesShares[1], 466.66 ether, 1 ether);

        assertEq(newOutcomesShares[0], 700 ether); // less likely outcome is increased by the amount
        // assertApproxEqAbs(Math.sqrt(newOutcomesShares[0] * newOutcomesShares[1]), liquidity + liquidityShares, 1e6);
        assertApproxEqAbs(423.98 ether, liquidity + liquidityShares, 1e16);
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
    function test_getRemoveLiquidityData_when_price_is_equal_V3() external view {
        // Arrange
        uint256 liquidityShares = 100 ether;
        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 600 ether;
        outcomeShares[2] = 600 ether;

        uint256 liquidity = MathUtils.cbrt(outcomeShares[0] * outcomeShares[1]*outcomeShares[2]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - amount;
        assertEq(newLiquidity, 500 ether);
        assertEq(outcomeSharesToReturn[0], 0);
        assertEq(outcomeSharesToReturn[1], 0);
        assertEq(outcomeSharesToReturn[2], 0);

        assertEq(newOutcomesShares[0], 500 ether);
        assertEq(newOutcomesShares[1], 500 ether);
        assertEq(newOutcomesShares[2], 500 ether);

        assertApproxEqAbs(MathUtils.cbrt(newOutcomesShares[0] * newOutcomesShares[1] * newOutcomesShares[2]), newLiquidity, 1e6);
    }

    function test_fuzz_getRemoveLiquidityData_when_price_is_equal_V3(uint256 liquidityShares, uint256 outcomeAmount)
        external
        view
    {
        // Arrange
        outcomeAmount = bound(outcomeAmount, 1, 9999999 ether);
        liquidityShares = bound(liquidityShares, 0, outcomeAmount);

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = outcomeAmount;
        outcomeShares[1] = outcomeAmount;
        outcomeShares[2] = outcomeAmount;

        uint256 liquidity = MathUtils.cbrt(outcomeShares[0] * outcomeShares[1] * outcomeShares[2]);

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
        assertEq(outcomeSharesToReturn[2], 0);

        assertEq(newOutcomesShares[0], outcomeAmount - liquidityShares);
        assertEq(newOutcomesShares[1], outcomeAmount - liquidityShares);
        assertEq(newOutcomesShares[2], outcomeAmount - liquidityShares);

        assertApproxEqAbs(MathUtils.cbrt(newOutcomesShares[0] * newOutcomesShares[1] * newOutcomesShares[2]), newLiquidity, 1e6);
    }

    /**
     * @notice Test the getRemoveLiquidityData function when the last liquidity provider exits and the price is equal
     *         The liquidity value in ETH should be equal to the liquidity shares to remove
     *         The outcome shares to give back to the user should be zero
     *         The new outcome shares in the market pool should be 0
     */
    function test_getRemoveLiquidityData_when_last_liquidity_provider_price_is_equal_V3() external view {
        // Arrange
        uint256 liquidityShares = 1000 ether;
        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        outcomeShares[2] = 1000 ether;

        uint256 liquidity = MathUtils.cbrt(outcomeShares[0] * outcomeShares[1]*outcomeShares[2]);

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
        assertEq(outcomeSharesToReturn[2], 0);

        assertEq(newOutcomesShares[0], 0);
        assertEq(newOutcomesShares[1], 0);
        assertEq(newOutcomesShares[2], 0);

        assertApproxEqAbs(MathUtils.cbrt(newOutcomesShares[0] * newOutcomesShares[1] * newOutcomesShares[2]), newLiquidity, 1e6);
    }

    /**
     * @notice Test the getRemoveLiquidityData function when the price is NOT equal
     *         The liquidity value in ETH should be less than the liquidity shares to remove
     *         The outcome shares to give back should be from the less likely outcome
     * @dev    The most likely outcome is the one with the lowest outcome shares
     */
    function test_getRemoveLiquidityData_when_price_is_NOT_equal_V3() external view {
        // Arrange
        uint256 liquidityShares = 100 ether;
        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 400 ether;
        outcomeShares[2] = 200 ether;

        uint256 liquidity = MathUtils.cbrt(outcomeShares[0] * outcomeShares[1]*outcomeShares[2]);

        // Act
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        uint256 newLiquidity = liquidity - liquidityShares;
        assertApproxEqAbs(amount, 60.57 ether, 0.01 ether);
        assertApproxEqAbs(newLiquidity, 263.42 ether, 0.01 ether);
        assertApproxEqAbs(outcomeSharesToReturn[0], 121.14 ether, 0.01 ether);
        assertApproxEqAbs(outcomeSharesToReturn[1], 60.57 ether, 0.01 ether);
        assertEq(outcomeSharesToReturn[2], 0);

        assertApproxEqAbs(newOutcomesShares[0], 418.29 ether, 0.01 ether);
        assertApproxEqAbs(newOutcomesShares[1], 278.86 ether, 0.01 ether);
        assertApproxEqAbs(newOutcomesShares[2], 139.43 ether, 0.01 ether);


        assertApproxEqAbs(MathUtils.cbrt(newOutcomesShares[0] * newOutcomesShares[1]* newOutcomesShares[2]), newLiquidity, 1e20); //@Note: deviation by 10 eth 
    }

    function test_fuzz_getRemoveLiquidityData_when_price_is_NOT_equal_V3(
        uint256 liquidityShares,
        uint256 outcomeAShares,
        uint256 outcomeBShares,
        uint256 outcomeCShares
    ) external view {
        // Arrange
        outcomeAShares = bound(outcomeAShares, 1, 99999999 ether);
        outcomeBShares = bound(outcomeBShares, 1, 99999999 ether);
        outcomeCShares = bound(outcomeCShares, 1, 99999999 ether);


        vm.assume(outcomeAShares != outcomeBShares && outcomeBShares != outcomeCShares);

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = outcomeAShares;
        outcomeShares[1] = outcomeBShares;
        outcomeShares[2] = outcomeCShares;

        uint256 liquidity = MathUtils.cbrt(
            Math.mulDiv(outcomeShares[0], outcomeShares[1], 1e18) * outcomeShares[2]
        );
        
        liquidityShares = bound(liquidityShares, 0, liquidity);

        // Act
        (uint256 liquidityValue, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            liquidityShares, IMarketAMM.MarketPoolState({liquidity: liquidity, outcomeShares: outcomeShares})
        );

        // Assert
        (
            uint256 mostLikely,
            uint256 midLikely,
            uint256 leastLikely
        ) = outcomeShares[0] < outcomeShares[1] &&
                outcomeShares[0] < outcomeShares[2]
                ? (
                    0,
                    outcomeShares[1] < outcomeShares[2] ? 1 : 2,
                    outcomeShares[1] < outcomeShares[2] ? 2 : 1
                )
                : outcomeShares[1] < outcomeShares[2]
                ? (
                    1,
                    outcomeShares[0] < outcomeShares[2] ? 0 : 2,
                    outcomeShares[0] < outcomeShares[2] ? 2 : 0
                )
                : (
                    2,
                    outcomeShares[0] < outcomeShares[1] ? 0 : 1,
                    outcomeShares[0] < outcomeShares[1] ? 1 : 0
                );

                
        uint256 newLiquidity = liquidity - liquidityShares;
        assertGe(liquidityValue, 0);
        assertGe(outcomeSharesToReturn[leastLikely], 0);
        assertGe(outcomeSharesToReturn[midLikely], 0);

        assertGe(newOutcomesShares[0], 0);
        assertGe(newOutcomesShares[1], 0);
        assertGe(newOutcomesShares[2], 0);


        uint256 newCbrt = MathUtils.cbrt(
            Math.mulDiv(newOutcomesShares[0], newOutcomesShares[1], 1e18) * newOutcomesShares[2]
        );
        assertApproxEqAbs(newCbrt, newLiquidity, 1e20);
        }


    /*//////////////////////////////////////////////////////////////
                            getBuyOutcomeData
    //////////////////////////////////////////////////////////////*/
    function test_getBuyOutcomeData_correctly_calculates_shares_V3()
        external
        view
    {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 1;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 400 ether;
        outcomeShares[2] = 200 ether;

        uint256 liquidity = 363.42 ether;

        // Act
        uint256 shares = marketAMM.getBuyOutcomeData(
            amount,
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertApproxEqAbs(shares, 271.42 ether, 0.1 ether); //@note: 0.1% error
    }

    /*//////////////////////////////////////////////////////////////
                            getSellOutcomeData
    //////////////////////////////////////////////////////////////*/
    function test_getSellOutcomeData_correctly_calculates_shares_V3()
        external
        view
    {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 400 ether;
        outcomeShares[2] = 200 ether;

        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        uint256 shares = marketAMM.getSellOutcomeData(
            amount,
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertApproxEqAbs(shares, 1100 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_correctly_calculates_shares_balanced_V3()
        external
        view
    {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 1;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 600 ether;
        outcomeShares[1] = 600 ether;
        outcomeShares[2] = 600 ether;

        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        uint256 shares = marketAMM.getSellOutcomeData(
            amount,
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertApproxEqAbs(shares, 364 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_correctly_calculates_large_amount_V3()
        external
        view
    {
        // Arrange
        uint256 amount = 10000 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 90 ether;
        outcomeShares[1] = 11000 ether;
        outcomeShares[2] = 12000 ether;

        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        uint256 shares = marketAMM.getSellOutcomeData(
            amount,
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertApproxEqAbs(shares, 15850 ether, 0.0001 ether);
    }

    function test_getSellOutcomeData_reverts_on_insufficient_liquidity_V3()
        external
    {
        // Arrange
        uint256 amount = 100 ether;
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 100 ether;
        outcomeShares[2] = 100 ether;
        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act & Assert
        vm.expectRevert(InsufficientLiquidity.selector);
        marketAMM.getSellOutcomeData(
            amount,
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                            getClaimLiquidityData
    //////////////////////////////////////////////////////////////*/
    function test_getClaimLiquidityData_correctly_calculates_amount()
        external
        view
    {
        // Arrange
        uint256 liquidityShares = 300 ether;
        uint256 resolvedOutcomeShares = 500 ether;
        uint256 liquidity = 1000 ether;

        // Act
        uint256 amount = marketAMM.getClaimLiquidityData(
            liquidityShares,
            resolvedOutcomeShares,
            liquidity
        );

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
    function test_getOutcomePrice_correctly_calculates_price_V3()
        external
        view
    {
        // Arrange
        uint256 outcomeIndex = 0;

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = 1000 ether;
        outcomeShares[1] = 1000 ether;
        outcomeShares[2] = 1000 ether;
        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        uint256 price = marketAMM.getOutcomePrice(
            outcomeIndex,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertApproxEqAbs(price, 0.3333 ether, 0.0001 ether);
    }

    function test_fuzz_getOutcomePrice_V3(
        uint256 outcomeAShares,
        uint256 outcomeBShares,
        uint256 outcomeCShares
    ) external view {
        // Arrange
        outcomeAShares = bound(outcomeAShares, 1, 9999999 ether);
        outcomeBShares = bound(outcomeBShares, 1, 9999999 ether);
        outcomeCShares = bound(outcomeCShares, 1, 9999999 ether);

        vm.assume(
            outcomeAShares != outcomeBShares && outcomeBShares != outcomeCShares
        );

        uint256[] memory outcomeShares = new uint256[](3);
        outcomeShares[0] = outcomeAShares;
        outcomeShares[1] = outcomeBShares;
        outcomeShares[2] = outcomeCShares;

        uint256 liquidity = MathUtils.cbrt(
            outcomeShares[0] * outcomeShares[1] * outcomeShares[2]
        );

        // Act
        uint256 priceA = marketAMM.getOutcomePrice(
            0,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );
        uint256 priceB = marketAMM.getOutcomePrice(
            1,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );
        uint256 priceC = marketAMM.getOutcomePrice(
            2,
            IMarketAMM.MarketPoolState({
                liquidity: liquidity,
                outcomeShares: outcomeShares
            })
        );

        // Assert
        assertGe(priceA, 0);
        assertLe(priceA, 1 ether);
        assertGe(priceB, 0);
        assertLe(priceB, 1 ether);
        assertGe(priceC, 0);
        assertLe(priceC, 1 ether);

        // Ensure the sum of all outcome prices is approximately 1 ether
        assertApproxEqAbs(priceA + priceB + priceC, 1 ether, 1e1);
    }
}
