// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IMarketAMM
 * @notice The interface for the MarketAMM contract used for calculations by the Market contract.
 */
interface IMarketAMM {
    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice The required Market pool data to calculate the return values
     * @param liquidity The current liquidity of the market
     * @param outcomeShares The current outcome shares of the market pool
     */
    struct MarketPoolState {
        uint256 liquidity;
        uint256[] outcomeShares;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Calculates the amount of liquidity shares and outcome shares to return when adding liquidity to the market
     * @param _amount The amount of ETH to add to the market
     * @param _marketParams The required Market pool data to calculate the liquidity shares and outcome shares to return
     * @return liquidityShares The amount of liquidity shares to mint
     * @return outcomeSharesToReturn The amount of outcome shares to give back to the user
     * @return newOutcomesShares The new outcome shares in the market pool
     */
    function getAddLiquidityData(uint256 _amount, MarketPoolState calldata _marketParams)
        external
        pure
        returns (uint256 liquidityShares, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares);

    /**
     * @notice Calculates the amount of ETH to return when removing liquidity from the market
     * @param _shares The amount of liquidity shares to remove
     * @param _marketParams The required Market pool data to calculate the ETH to return
     * @return amount The amount of ETH to return to the user
     * @return outcomeSharesToReturn The amount of outcome shares to give back to the user
     * @return newOutcomesShares The new outcome shares in the market pool
     */
    function getRemoveLiquidityData(uint256 _shares, MarketPoolState calldata _marketParams)
        external
        pure
        returns (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares);

    /**
     * @notice Calculates the amount of outcome shares to return when buying an outcome with ETH
     * @param _amount the amount of ETH to buy shares with
     * @param _outcomeIndex the index of the outcome to buy shares from
     * @param _marketParams the required Market pool data to calculate the outcome shares to return
     * @return shares The amount of outcome shares to give back to the user
     */
    function getBuyOutcomeData(uint256 _amount, uint256 _outcomeIndex, MarketPoolState calldata _marketParams)
        external
        pure
        returns (uint256 shares);

    /**
     * @notice Calculates the amount of shares to return when selling an outcome for ETH
     * @param _amount the amount of ETH to sell shares for
     * @param _outcomeIndex the index of the outcome to sell shares from
     * @param _marketParams the required Market pool data to calculate the shares to return
     * @return shares The amount of shares required by the user
     */
    function getSellOutcomeData(uint256 _amount, uint256 _outcomeIndex, MarketPoolState calldata _marketParams)
        external
        pure
        returns (uint256 shares);

    /**
     * @notice Calculates the liquidity value in ETH after the market is resolved
     * @param _liquidityShares the amount of liquidity shares to claim ETH for
     * @param _resolvedOutcomeShares the amount of outcome shares after the market is resolved
     * @param _liquidity the amount of liquidity in the market
     * @return amount The amount of ETH to return to the user
     */
    function getClaimLiquidityData(uint256 _liquidityShares, uint256 _resolvedOutcomeShares, uint256 _liquidity)
        external
        pure
        returns (uint256 amount);

    /**
     * @notice Returns the price of an outcome
     * @param _outcomeIndex the index of the outcome to get the price of
     * @param _totalAvailableShares the total tradeable outcome shares in the market pool
     * @param _marketParams the required Market pool data to calculate the outcome price
     * @return price of the outcome scaled by 1e18
     */
    function getOutcomePrice(
        uint256 _outcomeIndex,
        uint256 _totalAvailableShares,
        MarketPoolState calldata _marketParams
    ) external view returns (uint256 price);
}
