// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockOracle is Ownable {
    uint256 public winningOutcome;
    bool public isOutcomeSet;

    event WinningOutcomeSet(uint256 outcome);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Allows the owner to set the winning outcome.
     */
    function setWinningOutcome(uint256 outcome) external onlyOwner {
        require(!isOutcomeSet, "Outcome already set");
        winningOutcome = outcome;
        isOutcomeSet = true;

        emit WinningOutcomeSet(outcome);
    }

    /**
     * @dev Allows anyone to fetch the winning outcome.
     */
    function getWinningOutcome() external view returns (uint256) {
        require(isOutcomeSet, "Winning outcome not set yet");
        return winningOutcome;
    }

    /**
     * @dev Resets the oracle (for testing/replay scenarios).
     */
    function resetOutcome() external onlyOwner {
        winningOutcome = 0;
        isOutcomeSet = false;
    }
}
