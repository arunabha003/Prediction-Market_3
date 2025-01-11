// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDC} from "./../test/market.t.sol";
/**
 * @title PolymarketMarket
 * @notice An ERC1155-based 2-outcome prediction market:
 *         - ID=0: YES token
 *         - ID=1: NO token
 *         - ID=2: LP token
 *         Collateral is USDC. On resolution, winning shares redeem for 1 USDC each.
 *
 * UUPSUpgradeable + OwnableUpgradeable => upgradability with restricted _authorizeUpgrade.
 */
contract PolymarketMarket is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @dev outcome IDs
    uint256 public constant YES_TOKEN_ID = 0;
    uint256 public constant NO_TOKEN_ID = 1;
    uint256 public constant LP_TOKEN_ID = 2;

    /// @notice Associated USDC token
    MockUSDC public usdc;

    /// @notice Oracle (who can resolve the market)
    address public oracle;

    /// @notice Market question and close time
    string public question;
    uint256 public closeTime;

    /// @notice If the market is resolved, which outcome is the winner? (0=YES,1=NO)
    bool public resolved;
    uint256 public winningOutcome;

    /// @notice Reference to the AMM contract (can be separate or same)
    address public amm;

    /// @dev =============== Events ===============
    event MarketInitialized(
        string question,
        uint256 closeTime,
        address oracle
    );

    event MarketResolved(uint256 winningOutcome);
    event RedeemedWinnings(
        address indexed redeemer,
        uint256 outcome,
        uint256 sharesBurned,
        uint256 usdcReceived
    );

    /// @dev =============== Modifiers ===============
    modifier onlyOracle() {
        require(msg.sender == oracle, "Not oracle");
        _;
    }

    modifier marketNotResolved() {
        require(!resolved, "Market already resolved");
        _;
    }

    modifier marketOpen() {
        require(block.timestamp < closeTime, "Market closed");
        require(!resolved, "Market resolved");
        _;
    }


    

    /// @dev =============== UUPS Setup ===============
    function initialize(
        address _usdc,
        string memory _uri,
        string memory _question,
        uint256 _closeTime,
        address _oracle,
        address _amm
    ) public initializer {
        __ERC1155_init(_uri);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        require(_usdc != address(0), "Invalid USDC");
        require(_oracle != address(0), "Invalid oracle");
        require(_closeTime > block.timestamp, "Close time must be future");
        require(_amm != address(0), "Invalid AMM address");

        usdc = MockUSDC(_usdc);
        question = _question;
        closeTime = _closeTime;
        oracle = _oracle;
        amm = _amm;

        emit MarketInitialized(_question, _closeTime, _oracle);
    }

    /**
     * @notice Redeem winning shares for USDC, $1 per share.
     */
    function redeemWinnings(uint256 outcome, uint256 shares) external {
        require(resolved, "Not resolved");
        require(outcome == winningOutcome, "Not winning outcome");
        require(shares > 0, "Zero shares");

        uint256 userBalance = balanceOf(msg.sender, outcome);
        require(shares <= userBalance, "Insufficient shares");

        // Burn the shares
        _burn(msg.sender, outcome, shares);

        // Transfer USDC -> msg.sender
        bool ok = usdc.transferFrom(amm,msg.sender, shares);
        require(ok, "USDC transfer failed");

        emit RedeemedWinnings(msg.sender, outcome, shares, shares);
    }

    /**
     * @notice Oracle resolves the market
     */
    function resolveMarket(uint256 _winningOutcome)
        external
        onlyOracle
        marketNotResolved
    {
        require(_winningOutcome == YES_TOKEN_ID || _winningOutcome == NO_TOKEN_ID, "Invalid outcome");
        require(block.timestamp >= closeTime, "Market not closed yet");

        resolved = true;
        winningOutcome = _winningOutcome;

        emit MarketResolved(_winningOutcome);
    }

    /**
     * @notice Access point for AMM to mint or burn shares
     *         (When user buys or sells outcome tokens via AMM).
     */
    function mintShares(
        address to,
        uint256 outcome,
        uint256 amount
    ) external {
        require(msg.sender == amm, "Only AMM can mint");
        require(!resolved, "Already resolved");
        _mint(to, outcome, amount, "");
    }

    function burnShares(
        address from,
        uint256 outcome,
        uint256 amount
    ) external {
        require(msg.sender == amm, "Only AMM can burn");
    
        // If the outcome is YES or NO, block burning after resolution (freezes trading).
        // If it's the LP token (ID=2), allow even after resolution.
        if (outcome == 0 || outcome == 1) {
            require(!resolved, "Cannot burn outcome shares after resolved");
        }
    
        _burn(from, outcome, amount);
    }
    

    /**
     * @dev Required by UUPS to restrict who can upgrade
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
