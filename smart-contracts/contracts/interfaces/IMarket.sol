// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IMarket
 * @notice The interface for the Market contract
 */
interface IMarket {
    /*//////////////////////////////////////////////////////////////
                            ENUMS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Enum to represent the state of the market
     * @param open Market is open for trading
     * @param closed Market is closed for trading
     * @param resolved Market is resolved
     */
    enum MarketState {
        open,
        closed,
        resolved
    }

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Struct to store the shares of an outcome
     * @param total Total shares of the outcome
     * @param available The shares available for trading in the pool
     * @dev Takes 2 storage slots
     */
    struct Shares {
        uint256 total;
        uint256 available;
    }

    /**
     * @notice Struct to store the outcome of the market
     * @param name Name of the outcome
     * @param shares Shares of the outcome
     * @dev Takes 3 storage slots
     */
    struct Outcome {
        string name;
        Shares shares;
    }

    /**
     * @notice Struct to store the input data for initializing the market
     * @param question The question/name of the market
     * @param outcomeNames The names of the outcomes
     * @param closeTime The time after which the market will be closed for trading
     * @param resolveDelay The delay after the close time to resolve the market
     * @param feeBPS The fee basis points of the market
     * @param creator The address of the creator
     */
    struct MarketInfoInput {
        string question;
        string[] outcomeNames;
        uint256 closeTime;
        uint256 resolveDelay;
        uint256 feeBPS;
        address creator;
    }

    /**
     * @notice Struct to store the general information about the market
     * @param question The question/name of the market
     * @param outcomeCount The number of outcomes for the market
     * @param closeTime The time after which the market will be closed for trading
     * @param createTime The time when the market was created
     * @dev Takes 5 storage slots
     */
    struct MarketInfo {
        string question;
        uint256 outcomeCount;
        uint256 closeTime;
        uint256 createTime;
        uint256 closedAt;
    }

    /**
     * @notice Struct to store the data of the AMM pool
     * @param balance The balance of the pool in
     * @param liquidity The total liquidity value of the pool
     * @param totalAvailableShares The total tradeable shares
     * @param outcomeIds The IDs of the outcomes
     * @param outcomes The outcomes of the pool
     * @dev Takes 4 storage slots
     */
    struct MarketPoolData {
        uint256 balance;
        uint256 liquidity;
        uint256 totalAvailableShares;
        Outcome[] outcomes;
    }

    /**
     * @notice Struct to store the fees of the market
     * @param feeBPS The fee basis points of the market
     * @param poolWeight Internal variable for correct liquidity shares ratio-based fee calculation
     * @param totalFeesCollected The total fees collected by the market
     * @param claimed Internal variable for correct fee calculation
     * @param userClaimedFees The fees claimed by the user
     * @dev Takes 5 slots
     */
    struct MarketFees {
        uint256 feeBPS;
        uint256 poolWeight;
        uint256 totalFeesCollected;
        mapping(address => uint256) claimed;
        mapping(address => uint256) userClaimedFees;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the market is initialized
     * @param _question The question of the market
     * @param _outcomeCount The number of outcomes
     * @param _closeTime The time after which the market will be closed for trading
     * @param _creator The address of the creator
     * @param _oracle The address of the oracle
     * @param _marketAMM The address of the market AMM
     * @param _initialLiquidity The initial liquidity of the market
     * @param _resolveDelay The delay after the close time to resolve the market
     * @param _feeBPS The fee basis points of the market
     */
    event MarketInitialized(
        string _question,
        uint256 _outcomeCount,
        uint256 _closeTime,
        address _creator,
        address _oracle,
        address _marketAMM,
        uint256 _initialLiquidity,
        uint256 _resolveDelay,
        uint256 _feeBPS
    );

    /**
     * @notice Emitted when a user adds liquidity to the market
     * @param _provider The address of the liquidity provider
     * @param _amount The amount of ETH added
     * @param _liquidityShares The amount of liquidity shares received
     * @param _liquidity The total liquidity value of the pool
     */
    event LiquidityAdded(address indexed _provider, uint256 _amount, uint256 _liquidityShares, uint256 _liquidity);

    /**
     * @notice Emitted when a user removes liquidity from the market
     * @param _provider The address of the liquidity provider
     * @param _shares The amount of liquidity shares burned
     * @param _amount The amount of ETH received
     * @param _liquidity The total liquidity value of the pool
     */
    event LiquidityRemoved(address indexed _provider, uint256 _shares, uint256 _amount, uint256 _liquidity);

    /**
     * @notice Emitted when a user buys shares of an outcome
     * @param _buyer The address of the buyer
     * @param _outcomeIndex The index of the outcome
     * @param _amount The amount of ETH spent
     * @param _fee The fee deducted from the amount
     * @param _shares The amount of shares bought
     */
    event SharesBought(
        address indexed _buyer, uint256 indexed _outcomeIndex, uint256 _amount, uint256 _fee, uint256 _shares
    );

    /**
     * @notice Emitted when a user sells shares of an outcome
     * @param _seller The address of the seller
     * @param _outcomeIndex The index of the outcome
     * @param _amount The amount of ETH received
     * @param _fee The fee deducted from the amount
     * @param _shares The amount of shares sold
     */
    event SharesSold(
        address indexed _seller, uint256 indexed _outcomeIndex, uint256 _amount, uint256 _fee, uint256 _shares
    );

    /**
     * @notice Emitted when the market state updates
     * @param _updatedAt The time when the market's state was updated
     * @param _state The new state of the market
     */
    event MarketStateUpdated(uint256 _updatedAt, MarketState _state);

    /**
     * @notice Emitted when a user claims the rewards
     * @param _claimer The address of the claimer
     * @param _amount The amount of ETH claimed
     */
    event RewardsClaimed(address indexed _claimer, uint256 _amount);

    /**
     * @notice Emitted when a user claims the liquidity
     * @param _claimer The address of the claimer
     * @param _amount The amount of ETH claimed
     */
    event LiquidityClaimed(address indexed _claimer, uint256 _amount);

    /**
     * @notice Emitted when a user claims the fees
     * @param _claimer The address of the claimer
     * @param _amount The amount of ETH claimed
     */
    event FeesClaimed(address indexed _claimer, uint256 _amount);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Adds liquidity to the market
     *         The liquidity provider will receive liquidity shares and outcome shares depending on the current price:
     *         - If the market is balanced, the user will receive liquidity shares equal to the amount of ETH added
     *         - If the market is unbalanced, the user will receive liquidity shares and outcome shares of the most likely outcome
     * @param _amount The amount of ETH to add to the market
     * @param _deadline The deadline to add liquidity
     */
    function addLiquidity(uint256 _amount, uint256 _deadline) external payable;

    /**
     * @notice Removes liquidity fro, the market
     *         The liquidity provider will receive ETH and outcome shares depending on the current price:
     *         - If the market is balanced, the user will receive ETH equal to the amount of liquidity shares burned
     *         - If the market is unbalanced, the user will receive ETH and outcome shares of the least likely outcome
     * @param _shares The amount of shares to burn
     * @param _deadline The deadline to remove liquidity
     */
    function removeLiquidity(uint256 _shares, uint256 _deadline) external payable;

    /**
     * @notice Buys shares of an outcome in the market
     * @param _amount the amount of ETH to spend on shares
     * @param _outcomeIndex the index of the outcome to buy shares from
     * @param _minOutcomeShares the minimum amount of shares to buy
     * @param _deadline the deadline to buy shares
     */
    function buyShares(uint256 _amount, uint256 _outcomeIndex, uint256 _minOutcomeShares, uint256 _deadline)
        external
        payable;

    /**
     * @notice Sells shares of an outcome in the market
     * @param _receiveAmount the amount of ETH to receive for shares
     * @param _outcomeIndex the index of the outcome to sell shares from
     * @param _maxOutcomeShares the maximum amount of shares to sell
     * @param _deadline the deadline to sell shares
     */
    function sellShares(uint256 _receiveAmount, uint256 _outcomeIndex, uint256 _maxOutcomeShares, uint256 _deadline)
        external
        payable;

    /**
     * @notice Closes the market if the close time has passed
     *         The market will be closed for trading and the outcome will be resolved after a delay
     */
    function closeMarket() external;

    /**
     * @notice Resolves the market outcome index using the Oracle
     */
    function resolveMarket() external;

    /**
     * @notice Claims the rewards for the winning outcome
     */
    function claimRewards() external payable;

    /**
     * @notice Claims the liquidity from the market
     */
    function claimLiquidity() external payable;

    /**
     * @notice Claims the fees from the market
     */
    function claimFees() external payable;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the general information about the market
     * @return info The information of the market
     */
    function getInfo() external view returns (MarketInfo memory info);

    /**
     * @notice Returns the pool data of the market
     * @return poolData The data of the AMM pool
     */
    function getPoolData() external view returns (MarketPoolData memory poolData);

    /**
     * @notice Returns the delay after the close time, after which the market can be resolved
     * @return resolveDelay The delay after the close time to resolve the market
     */
    function getResolveDelay() external view returns (uint256 resolveDelay);

    /**
     * @notice Returns the fee BPS for buying and selling shares
     * @dev The fee is calculated as feeBPS / 10000
     */
    function getFeeBPS() external view returns (uint256 feeBPS);

    /**
     * @notice Returns the outcomes of the market
     * @return names The names of the outcomes
     * @return totalShares The total shares of the outcomes
     * @return poolShares The shares available for trading in the pool
     */
    function getOutcomes()
        external
        view
        returns (string[] memory names, uint256[] memory totalShares, uint256[] memory poolShares);

    /**
     * @notice Returns the shares of the user for a specific outcome
     * @return shares of the outcome
     */
    function getUserOutcomeShares(address _user, uint256 _outcomeIndex) external view returns (uint256 shares);

    /**
     * @notice Returns the liquidity shares of the user
     * @return shares of liquidity
     */
    function getUserLiquidityShares(address _user) external view returns (uint256 shares);

    /**
     * @notice Returns the price of an outcome
     * @param _outcomeIndex The index of the outcome to get the price of
     * @return price of the outcome scaled by 1e18
     */
    function getOutcomePrice(uint256 _outcomeIndex) external view returns (uint256 price);

    /**
     * @notice Returns the outcome index of the resolved outcome
     * @return outcomeIndex The index of the resolved outcome
     */
    function getResolveOutcomeIndex() external view returns (uint256 outcomeIndex);

    /**
     * @notice Returns the claimable fees of the user
     * @param _user The address of the user
     * @return amount The amount of fees claimable by the user
     */
    function getClaimableFees(address _user) external view returns (uint256 amount);

    /**
     * @notice Returns the total fees claimed by the user
     * @param _user The address of the user
     * @return claimedFees The total fees claimed by the user
     */
    function getUserClaimedFees(address _user) external view returns (uint256 claimedFees);
}
