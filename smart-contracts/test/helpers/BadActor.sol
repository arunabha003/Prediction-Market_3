// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IMarket} from "../../contracts/interfaces/IMarket.sol";

/**
 * @title BadActor
 * @notice A helper contract that reverts when receiving ETH
 */
contract BadActor {
    IMarket public market;

    constructor(address _market) {
        market = IMarket(_market);
    }

    function buyShares(uint256 _amount, uint256 _outcomeIndex) external payable {
        market.buyShares{value: _amount}(_amount, _outcomeIndex, 0, block.timestamp + 1 days);
    }

    function sellShares(uint256 _amount, uint256 _outcomeIndex) external {
        market.sellShares(_amount, _outcomeIndex, type(uint256).max, block.timestamp + 1 days);
    }

    function addLiquidity(uint256 _amount) external payable {
        market.addLiquidity{value: _amount}(_amount, block.timestamp + 1 days);
    }

    function removeLiquidity(uint256 _shares) external {
        market.removeLiquidity(_shares, block.timestamp + 1 days);
    }

    function claimRewards() external {
        market.claimRewards();
    }

    function claimLiquidity() external {
        market.claimLiquidity();
    }

    function claimFees() external {
        market.claimFees();
    }

    receive() external payable {
        revert("BadActor");
    }
}
