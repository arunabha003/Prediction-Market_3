// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title The interface for the required functions of the Oracle contract to be used in the Prediction Market contract
 * @notice The Oracle contract is used to resolve the outcome of the prediction market
 */
interface IOracle {
    /*//////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Throws an error if the outcome has not been resolved yet
     */
    error OutcomeNotResolvedYet();

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns whether the oracle has resolved the outcome
     * @return isResolved True if the oracle has resolved the outcome
     */
    function isResolved() external view returns (bool isResolved);

    /**
     * @notice Gets the outcome of the oracle
     * @param outcomeIndex The index of the outcome
     */
    function getOutcome() external view returns (uint256 outcomeIndex);
}
