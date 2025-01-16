// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title PredictionMarket
 * @notice A binary prediction market contract using an AMM-based approach to buy/sell outcome shares.
 * @dev This version uses manual resolution (no external oracle) and includes safety checks for arithmetic under/overflow.
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarket {
    // ---------------------------------------
    // Constants & Libraries
    // ---------------------------------------
    uint256 public constant ONE = 1e18;          // Used for 1.0 in fixed-point math
    uint256 public constant MAX_UINT_256 = type(uint256).max;

    // ---------------------------------------
    // Enums & Structs
    // ---------------------------------------

    /**
     * @notice Markets transition from 'open' -> 'closed' -> 'resolved'.
     */
    enum MarketState {
        open,
        closed,
        resolved
    }

    /**
     * @notice Types of actions users can take (buy, sell, addLiquidity, etc.).
     */
    enum MarketAction {
        buy,
        sell,
        addLiquidity,
        removeLiquidity,
        claimWinnings,
        claimLiquidity,
        claimFees,
        claimVoided
    }

    /**
     * @notice Contains all data for a particular market.
     */
    struct Market {
        // Timings and state management
        uint256 closesAtTimestamp;  // When market stops accepting trades
        MarketState state;          // Current market state (open/closed/resolved)

        // Liquidity and pool data
        uint256 balance;            // Total ETH held by the market
        uint256 liquidity;          // Total "liquidity shares" minted
        uint256 sharesAvailable;    // Sum of all outcome shares available in the pool

        mapping(address => uint256) liquidityShares;  // Track each user's liquidity share amount
        mapping(address => bool) liquidityClaims;      // Whether a user has claimed liquidity post-resolution

        // Outcomes (for a binary market => 2 outcomes)
        uint256[] outcomeIds;
        mapping(uint256 => MarketOutcome) outcomes;

        // Resolution info
        MarketResolution resolution;

        // Fee tracking
        MarketFees fees;
    }

    /**
     * @notice Holds fee parameters and each user's claimed portion.
     */
    struct MarketFees {
        uint256 value;                      // Fee rate, e.g. 1% = 1e16, in 1e18 precision
        uint256 poolWeight;                 // Tracks cumulative fees stored in the market
        mapping(address => uint256) claimed;// How much each address has already claimed from fees
    }

    /**
     * @notice Records how a market was resolved (outcomeId or voided).
     */
    struct MarketResolution {
        bool resolved;       // Always true once market is resolved
        uint256 outcomeId;   // If >= outcomeIds.length => voided
    }

    /**
     * @notice Data structure for each outcome in a market.
     */
    struct MarketOutcome {
        uint256 marketId;    // The market this outcome belongs to
        uint256 id;          // Outcome ID (0 or 1 in a binary market)
        Shares shares;       // Share balances & tracking for this outcome
    }

    /**
     * @notice Tracks shares for each outcome: total minted, available in pool, holders, etc.
     */
    struct Shares {
        uint256 total;                       // Total minted for this outcome
        uint256 available;                   // Shares available in the pool
        mapping(address => uint256) holders; // Each user's share balance for this outcome
        mapping(address => bool) claims;     // Whether user has claimed winnings if this outcome won
        mapping(address => bool) voidedClaims; // Whether user has claimed in a voided scenario
    }

    // ---------------------------------------
    // Storage
    // ---------------------------------------

    /**
     * @notice Fee rate in 1e18 precision (e.g., 1% => 1e16).
     */
    uint256 public fee;

    /**
     * @notice ERC20 token used to verify that a user holds enough balance to create a market.
     */
    IERC20 public token;

    /**
     * @notice Minimum ERC20 token balance required to create a market.
     */
    uint256 public requiredBalance;

    // Market tracking
    uint256[] private marketIds;           // List of all market IDs
    mapping(uint256 => Market) private markets; // Each market's data
    uint256 public marketIndex;            // Auto-increment for market IDs

    // ---------------------------------------
    // Events
    // ---------------------------------------

    /**
     * @notice Emitted when a new market is created.
     */
    event MarketCreated(
        address indexed user,
        uint256 indexed marketId,
        uint256 outcomes,
        string question,
        string image
    );

    /**
     * @notice Emitted for every user action (buy, sell, addLiquidity, etc.).
     */
    event MarketActionTx(
        address indexed user,
        MarketAction indexed action,
        uint256 indexed marketId,
        uint256 outcomeId,
        uint256 shares,
        uint256 value,
        uint256 timestamp
    );

    /**
     * @notice Emitted to keep track of changes in outcome price.
     */
    event MarketOutcomePrice(
        uint256 indexed marketId,
        uint256 indexed outcomeId,
        uint256 value,
        uint256 timestamp
    );

    /**
     * @notice Emitted to track liquidity changes.
     */
    event MarketLiquidity(
        uint256 indexed marketId,
        uint256 value,
        uint256 price,
        uint256 timestamp
    );

    /**
     * @notice Emitted when the market is manually resolved (or voided).
     */
    event MarketResolved(
        address indexed user,
        uint256 indexed marketId,
        uint256 outcomeId,
        uint256 timestamp
    );

    // ---------------------------------------
    // Modifiers
    // ---------------------------------------

    /**
     * @dev Checks that a marketId is valid (less than marketIndex).
     */
    modifier isMarket(uint256 marketId) {
        require(marketId < marketIndex, "Market not found");
        _;
    }

    /**
     * @dev Automatically transitions the market from 'open' to 'closed' if current time > closesAtTimestamp.
     */
    modifier timeTransitions(uint256 marketId) {
        Market storage market = markets[marketId];
        if (block.timestamp > market.closesAtTimestamp && market.state == MarketState.open) {
            nextState(marketId); // transition to closed
        }
        _;
    }

    /**
     * @dev Ensures the market is in the specific state.
     */
    modifier atState(uint256 marketId, MarketState _state) {
        require(markets[marketId].state == _state, "Market in incorrect state");
        _;
    }

    /**
     * @dev Ensures the market is NOT in the specific state.
     */
    modifier notAtState(uint256 marketId, MarketState _state) {
        require(markets[marketId].state != _state, "Market in incorrect state");
        _;
    }

    /**
     * @dev After function body, transitions market to the next state (open -> closed -> resolved).
     */
    modifier transitionNext(uint256 marketId) {
        _;
        nextState(marketId);
    }

    /**
     * @dev Checks that msg.sender has enough ERC20 token balance to create a market.
     */
    modifier mustHoldRequiredBalance() {
        require(
            token.balanceOf(msg.sender) >= requiredBalance,
            "Sender must hold the required ERC20 balance"
        );
        _;
    }

    // ---------------------------------------
    // Constructor / Initialization
    // ---------------------------------------

    /**
     * @param _fee Fee rate (e.g., 1% => 1e16) in 1e18 precision
     * @param _token An ERC20 token contract for the "mustHoldRequiredBalance" check
     * @param _requiredBalance Minimum token balance needed to create a market
     */
    constructor(
        uint256 _fee,
        IERC20 _token,
        uint256 _requiredBalance
    ) {
        require(_fee < ONE, "Fee must be less than 100%");
        fee = _fee;
        token = _token;
        requiredBalance = _requiredBalance;
    }

    // ---------------------------------------
    // Core Functions
    // ---------------------------------------

    /**
     * @notice Creates a new 2-outcome (binary) market with initial ETH stake.
     * @param question A short text describing the market question
     * @param image A reference to an image or metadata
     * @param closesAt Timestamp after which trading is disallowed
     * @param arbitrator Currently unused in logic, but included for expansion
     * @param outcomes Must be 2 for a binary market
     * @return The ID of the newly created market
     */
    function createMarket(
        string calldata question,
        string calldata image,
        uint256 closesAt,
        address arbitrator,
        uint256 outcomes
    ) external payable mustHoldRequiredBalance returns (uint256) {
        require(msg.value > 0, "Initial stake must be > 0");
        require(closesAt > block.timestamp, "Closing time must be in the future");
        require(arbitrator != address(0), "Invalid arbitrator address");
        require(outcomes == 2, "Only 2-outcome (binary) markets supported");

        uint256 marketId = marketIndex;
        marketIds.push(marketId);
        Market storage market = markets[marketId];

        // Basic initialization
        market.closesAtTimestamp = closesAt;
        market.state = MarketState.open;
        market.fees.value = fee;
        // Use MAX_UINT_256 to signify unresolved
        market.resolution.outcomeId = MAX_UINT_256;

        // Create the outcomes for this market
        for (uint256 i = 0; i < outcomes; i++) {
            market.outcomeIds.push(i);
            MarketOutcome storage outcome = market.outcomes[i];
            outcome.marketId = marketId;
            outcome.id = i;
        }

        // Provide initial liquidity with the user's stake
        _addLiquidity(marketId, msg.value);

        // Emit initial price events
        emitMarketOutcomePriceEvents(marketId);
        emit MarketCreated(msg.sender, marketId, outcomes, question, image);

        marketIndex += 1;
        return marketId;
    }

    /**
     * @notice Allows user to buy shares of a particular outcome with ETH.
     * @param marketId The ID of the market
     * @param outcomeId 0 or 1 for binary markets
     * @param minOutcomeSharesToBuy Slippage check (the user can specify a minimum shares they'd expect)
     */
    function buy(
        uint256 marketId,
        uint256 outcomeId,
        uint256 minOutcomeSharesToBuy
    ) external payable timeTransitions(marketId) atState(marketId, MarketState.open) {
        Market storage market = markets[marketId];
        require(outcomeId < market.outcomeIds.length, "Invalid outcomeId");

        uint256 value = msg.value;
        require(value > 0, "Must send ETH to buy");

        // AMM formula to get how many outcome shares the user will receive
        uint256 shares = calcBuyAmount(value, marketId, outcomeId);
        require(shares >= minOutcomeSharesToBuy, "Slippage: Not enough outcome shares bought");
        require(shares > 0, "Shares is zero");

        // Deduct a fee portion
        uint256 feeAmount = (value * market.fees.value) / ONE;
        market.fees.poolWeight += feeAmount;
        uint256 netValue = value - feeAmount;

        MarketOutcome storage outcome = market.outcomes[outcomeId];

        // Expand the total shares in the pool by netValue
        _addSharesToMarket(marketId, netValue);

        // The outcome must have enough shares available to give to user
        require(outcome.shares.available >= shares, "Pool has insufficient outcome shares");

        // Transfer outcome shares from pool -> user
        _transferOutcomeSharesFromPool(msg.sender, marketId, outcomeId, shares);

        // Emit events
        emit MarketActionTx(
            msg.sender,
            MarketAction.buy,
            marketId,
            outcomeId,
            shares,
            value,
            block.timestamp
        );
        emitMarketOutcomePriceEvents(marketId);
    }

    /**
     * @notice Allows user to sell a specific outcome's shares back to the pool for ETH.
     * @param marketId The ID of the market
     * @param outcomeId 0 or 1
     * @param desiredValue How much ETH the user wants to receive
     * @param maxOutcomeSharesToSell Slippage check (they won't sell more shares than this)
     */
    function sell(
        uint256 marketId,
        uint256 outcomeId,
        uint256 desiredValue,
        uint256 maxOutcomeSharesToSell
    ) external timeTransitions(marketId) atState(marketId, MarketState.open) {
        Market storage market = markets[marketId];
        require(outcomeId < market.outcomeIds.length, "Invalid outcomeId");

        // Figure out how many shares user must sell to get 'desiredValue' ETH
        uint256 shares = calcSellAmount(desiredValue, marketId, outcomeId);
        require(shares <= maxOutcomeSharesToSell, "Slippage: selling more shares than desired");
        require(shares > 0, "Shares is zero");

        MarketOutcome storage outcome = market.outcomes[outcomeId];
        require(outcome.shares.holders[msg.sender] >= shares, "User has insufficient shares");

        // Transfer shares from user -> pool
        _transferOutcomeSharesToPool(msg.sender, marketId, outcomeId, shares);

        // Fee portion
        require((ONE - fee) > 0, "Fee too large");
        uint256 feeAmount = (desiredValue * market.fees.value) / (ONE - fee);
        market.fees.poolWeight += feeAmount;

        uint256 valuePlusFees = desiredValue + feeAmount;
        require(market.balance >= valuePlusFees, "Market has insufficient balance");

        // Remove those shares from total pool supply
        _removeSharesFromMarket(marketId, valuePlusFees);

        // Pay user the desired ETH
        (bool sent, ) = msg.sender.call{value: desiredValue}("");
        require(sent, "ETH transfer failed");

        emit MarketActionTx(
            msg.sender,
            MarketAction.sell,
            marketId,
            outcomeId,
            shares,
            desiredValue,
            block.timestamp
        );
        emitMarketOutcomePriceEvents(marketId);
    }

    // ---------------------------------------
    // Liquidity
    // ---------------------------------------

    /**
     * @notice User can add liquidity to the pool, receiving liquidity shares in return.
     */
    function addLiquidity(uint256 marketId)
        external
        payable
        timeTransitions(marketId)
        atState(marketId, MarketState.open)
    {
        _addLiquidity(marketId, msg.value);
    }

    /**
     * @notice Removes liquidity shares from the market, returning proportionate ETH plus any leftover outcome shares.
     * @param marketId The ID of the market
     * @param shares The number of liquidity shares user wants to remove
     */
    function removeLiquidity(uint256 marketId, uint256 shares)
        external
        timeTransitions(marketId)
        atState(marketId, MarketState.open)
    {
        Market storage market = markets[marketId];
        require(market.liquidityShares[msg.sender] >= shares, "Insufficient liquidity shares");

        // Claim any fees user has before removing liquidity
        claimFees(marketId);

        // Rebalance fees pool
        _rebalanceFeesPool(marketId, shares, MarketAction.removeLiquidity);

        uint256[] memory outcomesShares = _getMarketOutcomesShares(marketId);
        uint256[] memory sendAmounts = new uint256[](outcomesShares.length);

        // We'll find the smallest outcome shares as a reference to determine the liquidity proportion
        uint256 poolWeight = MAX_UINT_256;
        for (uint256 i = 0; i < outcomesShares.length; i++) {
            if (outcomesShares[i] < poolWeight) {
                poolWeight = outcomesShares[i];
            }
        }

        require(market.liquidity > 0, "Market has no liquidity");
        uint256 liquidityAmount = (shares * poolWeight) / market.liquidity;

        // Calculate how many outcome shares to give back to user
        for (uint256 i = 0; i < outcomesShares.length; i++) {
            uint256 portion = (outcomesShares[i] * shares) / market.liquidity;
            // The leftover after rebalancing is sent to user
            sendAmounts[i] = (portion > liquidityAmount) ? portion - liquidityAmount : 0;
        }

        // Remove from the pool
        _removeSharesFromMarket(marketId, liquidityAmount);
        market.liquidity -= shares;
        market.liquidityShares[msg.sender] -= shares;

        // Transfer "surplus" outcome shares to user
        for (uint256 i = 0; i < outcomesShares.length; i++) {
            if (sendAmounts[i] > 0) {
                uint256 before = market.sharesAvailable;
                uint256 outcomeAvail = market.outcomes[i].shares.available;
                _transferOutcomeSharesFromPool(msg.sender, marketId, i, sendAmounts[i]);
                emit MarketActionTx(
                    msg.sender,
                    MarketAction.buy,
                    marketId,
                    i,
                    sendAmounts[i],
                    (before - outcomeAvail) * sendAmounts[i] / market.sharesAvailable,
                    block.timestamp
                );
            }
        }

        // Return the ETH portion from removing liquidity
        (bool sent, ) = msg.sender.call{value: liquidityAmount}("");
        require(sent, "ETH transfer failed");

        emit MarketActionTx(
            msg.sender,
            MarketAction.removeLiquidity,
            marketId,
            0,
            shares,
            liquidityAmount,
            block.timestamp
        );
        emit MarketLiquidity(marketId, market.liquidity, getMarketLiquidityPrice(marketId), block.timestamp);
    }

    // ---------------------------------------
    // Resolution & Claims
    // ---------------------------------------

    /**
     * @notice Manually resolves the market, transitioning from 'closed' to 'resolved'.
     * @param outcomeId If it's >= numberOfOutcomes => the market is voided
     */
    function manualResolveMarketOutcome(uint256 marketId, uint256 outcomeId)
        external
        timeTransitions(marketId) 
        atState(marketId, MarketState.closed)
        transitionNext(marketId)
    {
        Market storage market = markets[marketId];
        // If outcomeId >= outcomeIds.length => voided
        market.resolution.outcomeId = outcomeId;

        emit MarketResolved(msg.sender, marketId, outcomeId, block.timestamp);
        emitMarketOutcomePriceEvents(marketId);
    }

    /**
     * @notice Claims winnings from a resolved (non-voided) market.
     * @dev Each share in the winning outcome is worth 1 wei from the pool.
     */
    function claimWinnings(uint256 marketId)
        external
        atState(marketId, MarketState.resolved)
    {
        Market storage market = markets[marketId];
        uint256 outcomeId = market.resolution.outcomeId;

        require(!isMarketVoided(marketId), "Market is voided, no direct winnings");
        MarketOutcome storage resolvedOutcome = market.outcomes[outcomeId];
        uint256 userShares = resolvedOutcome.shares.holders[msg.sender];
        require(userShares > 0, "No winning shares owned");
        require(!resolvedOutcome.shares.claims[msg.sender], "Winnings already claimed");

        // 1 share => 1 wei
        uint256 value = userShares;
        require(market.balance >= value, "Insufficient market balance");

        // Deduct from market
        market.balance -= value;
        resolvedOutcome.shares.claims[msg.sender] = true;

        // Emit action
        emit MarketActionTx(
            msg.sender,
            MarketAction.claimWinnings,
            marketId,
            outcomeId,
            userShares,
            value,
            block.timestamp
        );

        // Transfer ETH to user
        (bool sent, ) = msg.sender.call{value: value}("");
        require(sent, "ETH transfer failed");
    }

    /**
     * @notice Allows users to claim their outcome shares if the market was voided.
     * @param outcomeId The outcome index the user holds shares in
     */
    function claimVoidedOutcomeShares(uint256 marketId, uint256 outcomeId)
        external
        atState(marketId, MarketState.resolved)
    {
        require(isMarketVoided(marketId), "Market is not voided");
        Market storage market = markets[marketId];
        MarketOutcome storage outcome = market.outcomes[outcomeId];

        uint256 userShares = outcome.shares.holders[msg.sender];
        require(userShares > 0, "User has no outcome shares");
        require(!outcome.shares.voidedClaims[msg.sender], "User already claimed voided shares");

        // The "price" in a void scenario is fractionally computed
        uint256 price = getMarketOutcomePrice(marketId, outcomeId);
        uint256 value = (price * userShares) / ONE;

        require(market.balance >= value, "Insufficient market balance");

        market.balance -= value;
        outcome.shares.voidedClaims[msg.sender] = true;

        emit MarketActionTx(
            msg.sender,
            MarketAction.claimVoided,
            marketId,
            outcomeId,
            userShares,
            value,
            block.timestamp
        );

        // Transfer ETH to user
        (bool sent, ) = msg.sender.call{value: value}("");
        require(sent, "ETH transfer failed");
    }

    /**
     * @notice After resolution, liquidity providers can claim their share of the final pool.
     */
    function claimLiquidity(uint256 marketId)
        external
        atState(marketId, MarketState.resolved)
    {
        Market storage market = markets[marketId];

        // Claim any pending fees first
        claimFees(marketId);

        uint256 userLiquidity = market.liquidityShares[msg.sender];
        require(userLiquidity > 0, "No liquidity shares");
        require(!market.liquidityClaims[msg.sender], "Liquidity already claimed");

        uint256 liquidityPrice = getMarketLiquidityPrice(marketId);
        uint256 value = (liquidityPrice * userLiquidity) / ONE;

        require(market.balance >= value, "Insufficient market balance");

        // Deduct from market
        market.balance -= value;
        market.liquidityClaims[msg.sender] = true;

        emit MarketActionTx(
            msg.sender,
            MarketAction.claimLiquidity,
            marketId,
            0,
            userLiquidity,
            value,
            block.timestamp
        );

        (bool sent, ) = msg.sender.call{value: value}("");
        require(sent, "ETH transfer failed");
    }

    /**
     * @notice Allows user to claim accumulated trading fees from the market's fee pool.
     */
    function claimFees(uint256 marketId) public {
        Market storage market = markets[marketId];
        uint256 claimable = getUserClaimableFees(marketId, msg.sender);
        if (claimable > 0) {
            market.fees.claimed[msg.sender] += claimable;

            (bool sent, ) = msg.sender.call{value: claimable}("");
            require(sent, "Fee transfer failed");
        }

        emit MarketActionTx(
            msg.sender,
            MarketAction.claimFees,
            marketId,
            0,
            market.liquidityShares[msg.sender],
            claimable,
            block.timestamp
        );
    }

    // ---------------------------------------
    // AMM Math
    // ---------------------------------------

    /**
     * @notice Calculates how many outcome shares a user would receive if they spend `amount` ETH on 'outcomeId'.
     * @dev Uses an AMM formula, factoring out fee, and then applying a product-based approach.
     */
    function calcBuyAmount(
        uint256 amount,
        uint256 marketId,
        uint256 outcomeId
    ) public view returns (uint256) {
        Market storage market = markets[marketId];
        uint256[] memory outcomesShares = _getMarketOutcomesShares(marketId);

        require(outcomeId < outcomesShares.length, "Invalid outcomeId");
        require(outcomesShares[outcomeId] > 0, "No liquidity in outcome");

        // Sub fee from the amount
        uint256 amountMinusFees = amount - ((amount * market.fees.value) / ONE);

        // Check outcome's pool balance
        uint256 buyTokenPoolBalance = outcomesShares[outcomeId];

        // We'll compute a final "endingOutcomeBalance" after mixing in amountMinusFees across other outcomes
        uint256 endingOutcomeBalance = buyTokenPoolBalance * ONE;
        for (uint256 i = 0; i < outcomesShares.length; i++) {
            if (i != outcomeId) {
                uint256 otherPool = outcomesShares[i];
                require(otherPool + amountMinusFees > 0, "Division by zero in buy calc");
                uint256 numerator = endingOutcomeBalance * otherPool;
                uint256 denominator = otherPool + amountMinusFees;
                require(denominator > 0, "denominator is zero");
                endingOutcomeBalance = _ceilDiv(numerator, denominator);
            }
        }
        require(endingOutcomeBalance > 0, "Ending outcome balance is zero");

        // shares = buyTokenPoolBalance + amountMinusFees - (endingOutcomeBalance / ONE)
        uint256 shares = buyTokenPoolBalance + amountMinusFees - _ceilDiv(endingOutcomeBalance, ONE);
        require(shares <= (buyTokenPoolBalance + amountMinusFees), "Underflow or unexpected shares");
        return shares;
    }

    /**
     * @notice Calculates how many outcome shares must be sold to receive `amount` ETH (post-fee).
     * @dev Inverse of calcBuyAmount, factoring the fee into the sale.
     */
    function calcSellAmount(
        uint256 amount,
        uint256 marketId,
        uint256 outcomeId
    ) public view returns (uint256) {
        Market storage market = markets[marketId];
        uint256[] memory outcomesShares = _getMarketOutcomesShares(marketId);

        require(outcomeId < outcomesShares.length, "Invalid outcomeId");
        require((ONE - market.fees.value) > 0, "Fee too large");

        // amountPlusFees = the pre-fee number of ETH user would have needed to produce 'amount'
        uint256 amountPlusFees = (amount * ONE) / (ONE - market.fees.value);

        uint256 sellTokenPoolBalance = outcomesShares[outcomeId];
        require(sellTokenPoolBalance > 0, "No liquidity in outcome to sell");

        uint256 endingOutcomeBalance = sellTokenPoolBalance * ONE;
        for (uint256 i = 0; i < outcomesShares.length; i++) {
            if (i != outcomeId) {
                uint256 otherPool = outcomesShares[i];
                require(otherPool > amountPlusFees, "Not enough liquidity in other outcome");
                uint256 numerator = endingOutcomeBalance * otherPool;
                uint256 denominator = otherPool - amountPlusFees;
                require(denominator > 0, "denominator is zero in sell calc");
                endingOutcomeBalance = _ceilDiv(numerator, denominator);
            }
        }
        require(endingOutcomeBalance > 0, "Ending outcome balance is zero");

        // shares = amountPlusFees + (endingOutcomeBalance / ONE) - sellTokenPoolBalance
        uint256 shares = amountPlusFees + _ceilDiv(endingOutcomeBalance, ONE) - sellTokenPoolBalance;
        return shares;
    }

    // ---------------------------------------
    // Internal Helpers
    // ---------------------------------------

    /**
     * @dev Internal function to handle adding liquidity to the market in one step.
     */
    function _addLiquidity(uint256 marketId, uint256 value)
        private
        timeTransitions(marketId)
        atState(marketId, MarketState.open)
    {
        require(value > 0, "Cannot add 0 liquidity");
        Market storage market = markets[marketId];

        uint256 liquidityAmount;
        uint256[] memory outcomesShares = _getMarketOutcomesShares(marketId);
        uint256[] memory sendBackAmounts = new uint256[](outcomesShares.length);

        // If there's existing liquidity, we rebalance to ensure the pool stays consistent
        if (market.liquidity > 0) {
            // Find the largest outcome shares
            uint256 poolWeight = 0;
            for (uint256 i = 0; i < outcomesShares.length; i++) {
                if (outcomesShares[i] > poolWeight) {
                    poolWeight = outcomesShares[i];
                }
            }
            require(poolWeight > 0, "Pool weight is zero");

            // Distribute new value proportionally
            for (uint256 i = 0; i < outcomesShares.length; i++) {
                uint256 part = (value * outcomesShares[i]) / poolWeight;
                sendBackAmounts[i] = value - part;
            }

            // Mint new liquidity shares proportionally to the existing pool
            liquidityAmount = (value * market.liquidity) / poolWeight;

            // Rebalance fees accordingly
            _rebalanceFeesPool(marketId, liquidityAmount, MarketAction.addLiquidity);
        } else {
            // If no prior liquidity, user gets liquidity shares = 'value'
            liquidityAmount = value;
        }

        // Update the total liquidity
        market.liquidity += liquidityAmount;
        market.liquidityShares[msg.sender] += liquidityAmount;

        // Add the incoming ETH to the share pool
        _addSharesToMarket(marketId, value);

        // Transfer "surplus" outcome shares back to user
        for (uint256 i = 0; i < sendBackAmounts.length; i++) {
            if (sendBackAmounts[i] > 0) {
                uint256 before = market.sharesAvailable;
                uint256 outcomeAvail = market.outcomes[i].shares.available;
                _transferOutcomeSharesFromPool(msg.sender, marketId, i, sendBackAmounts[i]);
                emit MarketActionTx(
                    msg.sender,
                    MarketAction.buy,
                    marketId,
                    i,
                    sendBackAmounts[i],
                    (before - outcomeAvail) * sendBackAmounts[i] / market.sharesAvailable,
                    block.timestamp
                );
            }
        }

        // Emit final info
        uint256 liquidityPrice = getMarketLiquidityPrice(marketId);
        uint256 liquidityValue = (liquidityPrice * liquidityAmount) / ONE;
        emit MarketActionTx(
            msg.sender,
            MarketAction.addLiquidity,
            marketId,
            0,
            liquidityAmount,
            liquidityValue,
            block.timestamp
        );
        emit MarketLiquidity(marketId, market.liquidity, liquidityPrice, block.timestamp);
    }

    /**
     * @dev Adjust the fee pool when liquidity is added or removed.
     */
    function _rebalanceFeesPool(
        uint256 marketId,
        uint256 liquidityShares,
        MarketAction action
    ) private {
        Market storage market = markets[marketId];
        if (market.liquidity == 0) {
            // No liquidity => nothing to rebalance
            return;
        }
        uint256 poolWeightShare = (liquidityShares * market.fees.poolWeight) / market.liquidity;
        if (action == MarketAction.addLiquidity) {
            // Add fees pool portion
            market.fees.poolWeight += poolWeightShare;
            market.fees.claimed[msg.sender] += poolWeightShare;
        } else {
            // removeLiquidity
            if (poolWeightShare > market.fees.poolWeight) {
                poolWeightShare = market.fees.poolWeight;
            }
            if (poolWeightShare > market.fees.claimed[msg.sender]) {
                poolWeightShare = market.fees.claimed[msg.sender];
            }
            market.fees.poolWeight -= poolWeightShare;
            market.fees.claimed[msg.sender] -= poolWeightShare;
        }
    }

    /**
     * @dev Moves the market from one state to the next in the enum (open->closed->resolved).
     */
    function nextState(uint256 marketId) private {
        Market storage market = markets[marketId];
        market.state = MarketState(uint256(market.state) + 1);
    }

    /**
     * @dev Emits price events for each outcome + a liquidity event.
     */
    function emitMarketOutcomePriceEvents(uint256 marketId) private {
        Market storage market = markets[marketId];
        for (uint256 i = 0; i < market.outcomeIds.length; i++) {
            emit MarketOutcomePrice(
                marketId,
                i,
                getMarketOutcomePrice(marketId, i),
                block.timestamp
            );
        }
        emit MarketLiquidity(
            marketId,
            market.liquidity,
            getMarketLiquidityPrice(marketId),
            block.timestamp
        );
    }

    /**
     * @dev Increases the total and available shares for each outcome by 'shares'.
     * Also adds the same amount to the market's balance.
     */
    function _addSharesToMarket(uint256 marketId, uint256 shares) private {
        Market storage market = markets[marketId];
        uint256 outcomeCount = market.outcomeIds.length;

        for (uint256 i = 0; i < outcomeCount; i++) {
            MarketOutcome storage outcome = market.outcomes[i];
            outcome.shares.available += shares;
            outcome.shares.total += shares;
            market.sharesAvailable += shares;
        }
        market.balance += shares;
    }

    /**
     * @dev Removes 'shares' worth of ETH from each outcome's available pool, and from the market balance.
     */
    function _removeSharesFromMarket(uint256 marketId, uint256 shares) private {
        Market storage market = markets[marketId];
        uint256 outcomeCount = market.outcomeIds.length;
        require(market.sharesAvailable >= shares * outcomeCount, "Insufficient pool shares to remove");
        require(market.balance >= shares, "Insufficient market balance to remove");

        for (uint256 i = 0; i < outcomeCount; i++) {
            MarketOutcome storage outcome = market.outcomes[i];
            outcome.shares.available -= shares;
            outcome.shares.total -= shares;
            market.sharesAvailable -= shares;
        }
        market.balance -= shares;
    }

    /**
     * @dev Moves 'shares' of a specific outcome from the pool to a user.
     */
    function _transferOutcomeSharesFromPool(
        address user,
        uint256 marketId,
        uint256 outcomeId,
        uint256 shares
    ) private {
        Market storage market = markets[marketId];
        MarketOutcome storage outcome = market.outcomes[outcomeId];

        require(outcome.shares.available >= shares, "Insufficient pool outcome shares");
        outcome.shares.holders[user] += shares;
        outcome.shares.available -= shares;
        market.sharesAvailable -= shares;
    }

    /**
     * @dev Moves 'shares' of a specific outcome from a user back into the pool.
     */
    function _transferOutcomeSharesToPool(
        address user,
        uint256 marketId,
        uint256 outcomeId,
        uint256 shares
    ) private {
        Market storage market = markets[marketId];
        MarketOutcome storage outcome = market.outcomes[outcomeId];

        require(outcome.shares.holders[user] >= shares, "User lacks outcome shares");
        outcome.shares.holders[user] -= shares;
        outcome.shares.available += shares;
        market.sharesAvailable += shares;
    }

    // ---------------------------------------
    // View Functions / Getters
    // ---------------------------------------

    /**
     * @notice Returns the list of all created market IDs.
     */
    function getMarkets() external view returns (uint256[] memory) {
        return marketIds;
    }

    /**
     * @notice Returns high-level market data (state, liquidity, balance, etc.).
     */
    function getMarketData(uint256 marketId)
        external
        view
        returns (
            MarketState,
            uint256,
            uint256,
            uint256,
            uint256,
            int256
        )
    {
        Market storage market = markets[marketId];
        return (
            market.state,
            market.closesAtTimestamp,
            market.liquidity,
            market.balance,
            market.sharesAvailable,
            getMarketResolvedOutcome(marketId)
        );
    }

    /**
     * @notice Returns the current price (ETH per liquidity share) for a given market.
     */
    function getMarketLiquidityPrice(uint256 marketId)
        public
        view
        returns (uint256)
    {
        Market storage market = markets[marketId];
        // If resolved & not voided => reference the winning outcome's available
        if (market.state == MarketState.resolved && !isMarketVoided(marketId)) {
            uint256 outcomeId = market.resolution.outcomeId;
            return (market.outcomes[outcomeId].shares.available * ONE) / market.liquidity;
        }

        // Otherwise, use (liquidity * #outcomes) / sharesAvailable
        uint256 outcomeCount = market.outcomeIds.length;
        if (market.sharesAvailable == 0) return 0;
        return (market.liquidity * (ONE * outcomeCount)) / market.sharesAvailable;
    }

    /**
     * @notice Returns the current price of an outcome in 1e18 precision (0 to 1).
     */
    function getMarketOutcomePrice(uint256 marketId, uint256 outcomeId)
        public
        view
        returns (uint256)
    {
        Market storage market = markets[marketId];
        MarketOutcome storage outcome = market.outcomes[outcomeId];

        // If resolved & not voided => winner=1, loser=0
        if (market.state == MarketState.resolved && !isMarketVoided(marketId)) {
            return (outcomeId == market.resolution.outcomeId) ? ONE : 0;
        }

        // If still open/closed or voided => price = (sharesAvailable - outcomeAvail) / sharesAvailable
        if (market.sharesAvailable == 0) return 0;
        return ((market.sharesAvailable - outcome.shares.available) * ONE) / market.sharesAvailable;
    }

    /**
     * @notice Returns the resolved outcome ID, or -1 if not resolved.
     */
    function getMarketResolvedOutcome(uint256 marketId)
        public
        view
        returns (int256)
    {
        Market storage market = markets[marketId];
        if (market.state != MarketState.resolved) {
            return -1; 
        }
        return int256(market.resolution.outcomeId);
    }

    /**
     * @notice Checks if the market ended up voided (outcomeId >= outcomeIds.length).
     */
    function isMarketVoided(uint256 marketId)
        public
        view
        returns (bool)
    {
        Market storage market = markets[marketId];
        if (market.state != MarketState.resolved) {
            return false;
        }
        return (market.resolution.outcomeId >= market.outcomeIds.length);
    }

    /**
     * @notice Returns the liquidity shares and outcome shares (0 & 1) for a given user.
     */
    function getUserMarketShares(uint256 marketId, address user)
        external
        view
        returns (
            uint256 userLiquidity,
            uint256 outcome0Shares,
            uint256 outcome1Shares
        )
    {
        Market storage market = markets[marketId];
        userLiquidity = market.liquidityShares[user];
        outcome0Shares = market.outcomes[0].shares.holders[user];
        outcome1Shares = market.outcomes[1].shares.holders[user];
    }

    /**
     * @notice Returns the fraction of total liquidity a user owns in the market.
     */
    function getUserLiquidityPoolShare(uint256 marketId, address user)
        external
        view
        returns (uint256)
    {
        Market storage market = markets[marketId];
        if (market.liquidity == 0) return 0;
        return (market.liquidityShares[user] * ONE) / market.liquidity;
    }

    /**
     * @notice Calculates how many fees a user can currently claim from this market.
     */
    function getUserClaimableFees(uint256 marketId, address user)
        public
        view
        returns (uint256)
    {
        Market storage market = markets[marketId];
        if (market.liquidity == 0) return 0;

        // rawAmount = user's fraction of fees in 'poolWeight'
        uint256 rawAmount = (market.fees.poolWeight * market.liquidityShares[user]) / market.liquidity;
        uint256 claimedSoFar = market.fees.claimed[user];
        if (claimedSoFar >= rawAmount) {
            return 0;
        }
        return rawAmount - claimedSoFar;
    }

    /**
     * @dev Returns an array of the "available" shares in each outcome for a market.
     */
    function _getMarketOutcomesShares(uint256 marketId)
        private
        view
        returns (uint256[] memory)
    {
        Market storage market = markets[marketId];
        uint256 outcomeCount = market.outcomeIds.length;
        uint256[] memory arr = new uint256[](outcomeCount);
        for (uint256 i = 0; i < outcomeCount; i++) {
            arr[i] = market.outcomes[i].shares.available;
        }
        return arr;
    }

    /**
     * @dev Ceil-div helper that ensures we do integer division rounding up: (numerator + denominator - 1) / denominator
     */
    function _ceilDiv(uint256 numerator, uint256 denominator)
        private
        pure
        returns (uint256)
    {
        require(denominator > 0, "Denominator is zero");
        if (numerator == 0) return 0;
        return (numerator - 1) / denominator + 1;
    }
}
