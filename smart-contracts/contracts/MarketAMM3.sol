// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./errors/MarketErrors.sol";

import {IMarketAMM} from "./interfaces/IMarketAMM3.sol";

/**
 * @title MarketAMM
 * @notice The MarketAMM is a contract, used for calculations by the Market contract for each action
 * @notice The current version:
 *         - supports binary outcomes only
 */
contract MarketAMM3 is IMarketAMM {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 constant ONE = 1e18;

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL PURE
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Calculates the amount of liquidity shares and outcome shares to return when adding liquidity to the market
     * @param _amount The amount of ETH to add to the market
     * @param _marketParams The required Market pool data to calculate the liquidity shares and outcome shares to return
     * @return liquidityShares The amount of liquidity shares to mint
     * @return outcomeShareToReturn The amount of outcome shares to give back to the user
     * @return newOutcomeShares The new outcome shares in the market pool
     */
    function getAddLiquidityData(
        uint256 _amount,
        MarketPoolState calldata _marketParams
    )
        external
        pure
        returns (
            uint256 liquidityShares,
            uint256[] memory outcomeShareToReturn,
            uint256[] memory newOutcomeShares
        )
    {
        uint256 outcomeCount = _marketParams.outcomeShares.length;
        uint256[] memory outcomeShares = _marketParams.outcomeShares;

        outcomeShareToReturn = new uint256[](outcomeCount);
        newOutcomeShares = new uint256[](outcomeCount);

        for (uint256 i = 0; i < outcomeCount; ++i) {
            newOutcomeShares[i] = outcomeShares[i] + _amount;
        }

        if (_marketParams.liquidity == 0) {
            return (_amount, outcomeShareToReturn, newOutcomeShares);
        } else {
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

            newOutcomeShares[mostLikely] = newOutcomeShares[leastLikely].mulDiv(
                outcomeShares[mostLikely],
                outcomeShares[leastLikely]
            );

            newOutcomeShares[midLikely] = newOutcomeShares[leastLikely].mulDiv(
                outcomeShares[midLikely],
                outcomeShares[leastLikely]
            );

            liquidityShares = _amount.mulDiv(
                _marketParams.liquidity,
                outcomeShares[leastLikely]
            );

            outcomeShareToReturn[mostLikely] =
                outcomeShares[mostLikely] +
                _amount -
                newOutcomeShares[mostLikely];
            outcomeShareToReturn[midLikely] =
                outcomeShares[midLikely] +
                _amount -
                newOutcomeShares[midLikely];
        }
    }

    /**
     * @notice Calculates the amount of ETH to return when selling removing liquidity from the market
     * @param _shares The amount of liquidity shares to remove
     * @param _marketParams The required Market pool data to calculate the ETH to return
     * @return liquidityValue The value of the liquidity shares to in ETH
     * @return outcomeSharesToReturn The amount of outcome shares to give back to the user
     * @return newOutcomeShares The new outcome shares in the market pool
     */
    function getRemoveLiquidityData(
        uint256 _shares,
        MarketPoolState calldata _marketParams
    )
        external
        pure
        returns (
            uint256 liquidityValue,
            uint256[] memory outcomeSharesToReturn,
            uint256[] memory newOutcomeShares
        )
    {
        uint256 outcomeCount = _marketParams.outcomeShares.length;
        uint256[] memory outcomeShares = _marketParams.outcomeShares;

        outcomeSharesToReturn = new uint256[](outcomeCount);
        newOutcomeShares = new uint256[](outcomeCount);

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

        uint256 leastLikelyShares = outcomeShares[leastLikely];
        uint256 midLikelyShares = outcomeShares[midLikely];
        uint256 mostLikelyShares = outcomeShares[mostLikely];


        liquidityValue = _shares.mulDiv(_marketParams.liquidity, leastLikelyShares);

        for (uint256 i = 0; i < outcomeCount; ++i) {
            newOutcomeShares[i] = outcomeShares[i] - liquidityValue;
        }

        newOutcomeShares[leastLikely] = newOutcomeShares[mostLikely].mulDiv(
            leastLikelyShares,
            mostLikelyShares
        );

        newOutcomeShares[midLikely] = newOutcomeShares[mostLikely].mulDiv(
            midLikelyShares,
            mostLikelyShares
        );

        outcomeSharesToReturn[leastLikely] =leastLikelyShares -newOutcomeShares[leastLikely] -liquidityValue;
        outcomeSharesToReturn[midLikely] =midLikelyShares - newOutcomeShares[midLikely] -liquidityValue;
    }

    /**
     * @notice Calculates the amount of outcome shares to return when buying an outcome with ETH
     * @param _amount the amount of ETH to buy shares with
     * @param _outcomeIndex the index of the outcome to buy shares from
     * @param _marketParams the required Market pool data to calculate the outcome shares to return
     * @return shares The amount of outcome shares to give back to the user
     */
    function getBuyOutcomeData(
        uint256 _amount,
        uint256 _outcomeIndex,
        MarketPoolState calldata _marketParams
    ) external pure returns (uint256 shares) {
        uint256 oppositeIndex1 = (_outcomeIndex + 1) % 3;
        uint256 oppositeIndex2 = (_outcomeIndex + 2) % 3;
        uint256[] memory outcomeShares = _marketParams.outcomeShares;

        uint256 oppositeShares1 = outcomeShares[oppositeIndex1] + _amount;
        uint256 oppositeShares2 = outcomeShares[oppositeIndex2] + _amount;

        uint256 newBuyShares = getInvariant(
            _marketParams.liquidity,
            outcomeShares.length
        ).ceilDiv(oppositeShares1 * oppositeShares2);

        shares = outcomeShares[_outcomeIndex] + _amount - newBuyShares;
    }

    /**
     * @notice Calculates the amount of shares to return when selling an outcome for ETH
     * @param _amount the amount of ETH to sell shares for
     * @param _outcomeIndex the index of the outcome to sell shares from
     * @param _marketParams the required Market pool data to calculate the shares to return
     * @return shares The amount of shares to give back to the user
     */
    function getSellOutcomeData(
        uint256 _amount,
        uint256 _outcomeIndex,
        MarketPoolState calldata _marketParams
    ) external pure returns (uint256 shares) {
        uint256 oppositeIndex1 = (_outcomeIndex + 1) % 3;
        uint256 oppositeIndex2 = (_outcomeIndex + 2) % 3;
        uint256[] memory outcomeShares = _marketParams.outcomeShares;
        uint256 oppositeShares1 = outcomeShares[oppositeIndex1] - _amount;
        uint256 oppositeShares2 = outcomeShares[oppositeIndex2] - _amount;
        if (oppositeShares1 == 0 || oppositeShares2 == 0) {
            revert InsufficientLiquidity();
        }

        uint256 newSellShares = getInvariant(
            _marketParams.liquidity,
            outcomeShares.length
        ).ceilDiv(oppositeShares1 * oppositeShares2);

        shares = newSellShares + _amount - outcomeShares[_outcomeIndex];
    }

    /**
     * @notice Calculates the liquidity value in ETH after the market is resolved
     * @param _liquidityShares the amount of liquidity shares to claim
     * @param _resolvedOutcomeShares the amount of outcome shares after the market is resolved
     * @param _liquidity the amount of liquidity in the market
     * @return amount The amount of ETH to return to the user
     */
    function getClaimLiquidityData(
        uint256 _liquidityShares,
        uint256 _resolvedOutcomeShares,
        uint256 _liquidity
    ) external pure returns (uint256 amount) {
        amount = _liquidityShares.mulDiv(_resolvedOutcomeShares, _liquidity);
    }

    /**
     * @notice Returns the price of an outcome
     * @param _outcomeIndex the index of the outcome to get the price of
     * @param _marketParams the required Market pool data to calculate the outcome price
     * @return price of the outcome scaled by 1e18
     */
    function getOutcomePrice(
        uint256 _outcomeIndex,
        MarketPoolState calldata _marketParams
    ) external pure returns (uint256 price) {
        uint256[] memory outcomeShares = _marketParams.outcomeShares;

        uint256 oppositeIndex1 = (_outcomeIndex + 1) % 3;
        uint256 oppositeIndex2 = (_outcomeIndex + 2) % 3;

        uint256 weight = outcomeShares[oppositeIndex1] *
            outcomeShares[oppositeIndex2];

        uint256 totalPriceWeight = (outcomeShares[0] * outcomeShares[1]) +
            (outcomeShares[1] * outcomeShares[2]) +
            (outcomeShares[0] * outcomeShares[2]);

        return weight.mulDiv(ONE, totalPriceWeight);
    }

    /*//////////////////////////////////////////////////////////////
                             PRIVATE PURE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the invariant of the pool
     * @param liquidity the liquidity value of the pool
     * @param outcomeCount the total number of outcomes in the pool
     */
    function getInvariant(
        uint256 liquidity,
        uint256 outcomeCount
    ) private pure returns (uint256) {
        return liquidity ** outcomeCount;
    }
}
