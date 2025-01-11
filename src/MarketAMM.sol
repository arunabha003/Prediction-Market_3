// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Market.sol";
import {MockUSDC} from "./../test/market.t.sol";

/**
 * @title PolymarketAMM
 * @notice A simple 2-outcome AMM using constant-product, referencing PolymarketMarket for shares.
 *         - outcome IDs: 0=YES,1=NO
 *         - LP tokens have ID=2
 */
contract PolymarketAMM is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @dev references
    PolymarketMarket public market;
    MockUSDC public usdc;

    /// @dev Virtual reserves for outcome 0 (YES) and outcome 1 (NO)
    uint256 public reserveYes;
    uint256 public reserveNo;

    /// @dev total supply of LP tokens
    uint256 public totalLPSupply;

    /// @dev fee in basis points (e.g. 100 => 1%)
    uint256 public feeBps;
    uint256 public constant FEE_DENOM = 10_000;

    /// @dev events
    event LiquidityAdded(address indexed provider, uint256 usdcAmount, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 lpBurned, uint256 usdcReturned);
    event SharesBought(address indexed buyer, uint256 outcome, uint256 sharesOut, uint256 usdcIn);
    event FeeUpdated(uint256 newFeeBps);

    /// @dev modifiers
    modifier marketOpen() {
        require(!market.resolved(), "Market resolved");
        require(block.timestamp < market.closeTime(), "Market closed");
        _;
    }

    function initialize(
        address _market,
        uint256 _feeBps
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        market = PolymarketMarket(_market);
        usdc = MockUSDC(market.usdc());
        feeBps = _feeBps;
    }

    /// @dev Required by UUPS to restrict who can upgrade
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @notice Provide USDC liquidity. Splits USDC into 'Yes' and 'No' reserves.
     */
    function addLiquidity(uint256 usdcAmount) external marketOpen {
        require(usdcAmount > 0, "Zero USDC");

        // Transfer USDC in
        bool ok = usdc.transferFrom(msg.sender, address(this), usdcAmount);
        require(ok, "USDC transfer failed");

        if (totalLPSupply == 0 && reserveYes == 0 && reserveNo == 0) {
            // init: half to yes, half to no
            // uint256 half = usdcAmount / 2;
            reserveYes = usdcAmount;
            reserveNo = usdcAmount;

            // LP minted = total usdc
            totalLPSupply = usdcAmount;
            // Mint LP tokens (ID=2) to user
            market.mintShares(msg.sender, 2, usdcAmount);

            emit LiquidityAdded(msg.sender, usdcAmount, usdcAmount);
        } else if(reserveNo==reserveYes)
        {
            reserveYes += usdcAmount;
            reserveNo += usdcAmount;

            totalLPSupply += usdcAmount;
            market.mintShares(msg.sender, 2, usdcAmount);
        }
        else {
            // // Pro-rata approach
            uint256 currentTotal = reserveYes + reserveNo;
            uint256 lpMinted = (usdcAmount * totalLPSupply) / currentTotal; 

            totalLPSupply += lpMinted;
            market.mintShares(msg.sender, 2, lpMinted);

            // Distribute proportionally
            uint256 yesAdd = (reserveYes * usdcAmount) / currentTotal;
            uint256 noAdd = usdcAmount - yesAdd;

            reserveYes += yesAdd;
            reserveNo += noAdd;

            // emit LiquidityAdded(msg.sender, usdcAmount, lpMinted);

            // reserveYes += usdcAmount;
            // reserveNo += usdcAmount;

            // (uint256 probYES, uint256 probNO)=returnProbabilities();

            // if(probYES>probNO)
            // {
            //     uint256 LPtoMint = (usdcAmount * probYES) / 1e6;

            //     market.mintShares(msg.sender, 0, LPtoMint);
            //     market.mintShares(msg.sender, 2, usdcAmount-LPtoMint);
            //     emit LiquidityAdded(msg.sender, usdcAmount, LPtoMint);
            // }
            // else
            // {
            //     uint256 LPtoMint = (usdcAmount * probNO) / 1e6;

            //     market.mintShares(msg.sender, 1, LPtoMint);
            //     market.mintShares(msg.sender, 2, usdcAmount-LPtoMint);
            //     emit LiquidityAdded(msg.sender, usdcAmount, LPtoMint);

            // }


        }
    }

    

    /**
     * @notice Remove liquidity for your LP tokens. Get USDC back.
     */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "Zero LP");
        uint256 userLPBal = market.balanceOf(msg.sender, 2);
        require(lpAmount <= userLPBal, "Not enough LP");
    

        uint256 currentBalance = usdc.balanceOf(address(this));
        // If no other logic has changed the contract's balance, 
        // this should reflect the real amount of USDC that can be paid out.
    
        // 2) compute the user’s pro rata share of that real balance
        uint256 usdcOut = (lpAmount * currentBalance) / totalLPSupply;
    
        // 3) burn the user’s LP tokens
        market.burnShares(msg.sender, 2, lpAmount);
        totalLPSupply -= lpAmount;
    
    
        // 5) do the actual transfer
        bool ok = usdc.transfer(msg.sender, usdcOut);
        require(ok, "USDC transfer failed");
    
        emit LiquidityRemoved(msg.sender, lpAmount, usdcOut);
    }
    

    /**
     * @notice Buy outcome shares (0=YES or 1=NO) with USDC via x*y=k
     */
    function buyShares(uint256 outcome, uint256 usdcIn) external marketOpen {
        require(usdcIn > 0, "No USDC");
        require(
            outcome == market.YES_TOKEN_ID() || outcome == market.NO_TOKEN_ID(),
            "Invalid outcome"
        );
    
        bool ok = usdc.transferFrom(msg.sender, address(this), usdcIn);
        require(ok, "USDC transfer failed");
    
        // Apply fee
        uint256 fee = (usdcIn * feeBps) / FEE_DENOM;
        uint256 tradeAmount = usdcIn - fee;
    
        // Constant product
        uint256 oldK = reserveYes * reserveNo;
        uint256 sharesOut;
    
        // Scale probabilities to avoid integer division issues
        uint256 totalReserve = reserveYes + reserveNo;
        require(totalReserve > 0, "No reserves"); // Ensure non-zero reserves
    
        uint256 probYES = (reserveNo * 1e6) / totalReserve;
        uint256 probNO = (reserveYes * 1e6) / totalReserve;
    
        if (outcome == market.YES_TOKEN_ID()) {
            // Calculate shares to buy
            uint256 sharesToBuy = (tradeAmount * 1e6) / probYES;
            
            // Check if shares to buy exceed available YES shares
            require(sharesToBuy <= reserveYes, "Insufficient YES shares available");
    
            uint256 newReserveYes = reserveYes - sharesToBuy;
            uint256 newReserveNo = oldK / newReserveYes;
    
            require(newReserveYes > 0, "Invalid YES reserve");
            require(newReserveNo > reserveNo, "Slippage error");
    
            sharesOut = sharesToBuy;
    
            // Update reserves
            reserveNo = newReserveNo;
            reserveYes = newReserveYes;
        } else {
            // Calculate shares to buy
            uint256 sharesToBuy = (tradeAmount * 1e6) / probNO;
    
            // Check if shares to buy exceed available NO shares
            require(sharesToBuy <= reserveNo, "Insufficient NO shares available");
    
            uint256 newReserveNo = reserveNo - sharesToBuy;
            uint256 newReserveYes = oldK / newReserveNo;
    
            require(newReserveNo > 0, "Invalid NO reserve");
            require(newReserveYes > reserveYes, "Slippage error");
    
            sharesOut = sharesToBuy;
    
            // Update reserves
            reserveNo = newReserveNo;
            reserveYes = newReserveYes;
        }
    
        // Mint outcome shares
        market.mintShares(msg.sender, outcome, sharesOut);
    
        emit SharesBought(msg.sender, outcome, sharesOut, usdcIn);
    }



    function returnProbabilities() public view returns (uint256, uint256) {
        uint256 totalReserve = reserveYes + reserveNo;
        require(totalReserve > 0, "No reserves"); // Ensure non-zero reserves

        uint256 probYES = (reserveNo * 1e6) / totalReserve;
        uint256 probNO = (reserveYes * 1e6) / totalReserve;

        return (probYES, probNO);
    }
    

    /**
     * @notice Owner can update fees
     */
    function setFee(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 300, "Fee too high"); // e.g., max 3%
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    /// @notice utility
    function getPriceYes() external view returns (uint256) {
        // approximate
        if (reserveYes == 0) return 0;
        return (reserveNo * 1e6) / reserveYes;
    }

    function getPriceNo() external view returns (uint256) {
        if (reserveNo == 0) return 0;
        return (reserveYes * 1e6) / reserveNo;
    }

    function setMarket(address _market) external onlyOwner {
        require(address(market) == address(0), "Market already set");
        market = PolymarketMarket(_market);
        usdc = MockUSDC(market.usdc());
    }

}
