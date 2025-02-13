// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./errors/CommonErrors.sol";
import "./errors/MarketErrors.sol";

import {IMarket} from "./interfaces/IMarket.sol";
import {IMarketAMM} from "./interfaces/IMarketAMM3.sol";
import {IOracle} from "./interfaces/IOracle.sol";


/**
 * @title Market
 * @notice The Market contract represents a prediction market, where users can bet on the outcome of a question.
 * @notice The current version of the market:
 *         - uses ETH as the trading currency.
 *         - supports binary outcomes only
 */
contract Market is IMarket, Initializable {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 constant ONE = 1e18;
    uint256 constant BPS = 10000;
    uint256 constant MIN_RESOLVE_DELAY = 1 minutes;
    uint256 constant MAX_RESOLVE_DELAY = 7 days;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// Slot 0
    uint256 public resolveDelay; // The delay after the close time, after which the market can be resolved

    /// Slot 1 to 5
    MarketInfo public info; // General information about the market

    /// Slot 6 to 9
    MarketPoolData public poolData; // The pool data of the market

    /// Slot 10 to 14
    MarketFees public fees; // The fees data of the market

    /// Slot 15
    uint256 private resolvedOutcomeIndex; // The index of the resolved outcome

    /// Slot 16
    MarketState public state; // The state of the market
    address public creator; // The creator of the market

    /// Slot 17
    IOracle public oracle; // The oracle address of the market that will provide the outcome

    /// Slot 18
    IMarketAMM public marketAMM; // The MarketAMM contract used for calculations

    /// Slot 19
    mapping(address => mapping(uint256 => uint256)) userToOutcomeIndexToShares; // Mapping of user address to their outcome shares

    /// Slot 20
    mapping(address => uint256) userToLiquidityShares; // Mapping of user address to their liquidity shares

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the Market contract
     * @param _marketInfo The general information of the market
     * @param _oracle The oracle address of the market
     * @param _marketAMM The MarketAMM contract used for calculations
     * @param _initialLiquidity The initial liquidity of the market, added by the creator
     */
    function initialize(
        MarketInfoInput calldata _marketInfo,
        IOracle _oracle,
        IMarketAMM _marketAMM,
        uint256 _initialLiquidity
    ) external payable initializer {
        _initMarketInfo(_marketInfo);
        _initOutcomes(_marketInfo.outcomeNames);
        _initAddresses(_marketInfo.creator, _oracle, _marketAMM);
        _initFeeBPS(_marketInfo.feeBPS);

        _setMarketState(MarketState.open);

        _addLiquidity(_marketInfo.creator, _initialLiquidity);

        _emitMarketInit();
    }

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    modifier onlyAtState(MarketState _state) {
        if (state != _state) {
            revert InvalidMarketState();
        }
        _;
    }

    modifier notClosed() {
        if (info.closeTime <= block.timestamp) {
            revert MarketClosed();
        }
        _;
    }

    modifier matchingAmount(uint256 _amount) {
        if (_amount != msg.value) {
            revert AmountMismatch(_amount, msg.value);
        }
        _;
    }

    modifier validDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) {
            revert DeadlinePassed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Adds liquidity to the market
     *         The liquidity provider will receive liquidity shares and outcome shares depending on the current price:
     *         - If the market is balanced, the user will receive liquidity shares equal to the amount of ETH added
     *         - If the market is unbalanced, the user will receive liquidity shares and outcome shares of the most likely outcome
     * @param _amount The amount of ETH to add to the market
     */
    function addLiquidity(uint256 _amount, uint256 _deadline) external payable validDeadline(_deadline) {
        _addLiquidity(msg.sender, _amount);
    }

    /**
     * @notice Removes liquidity from the market
     *         The liquidity provider will receive ETH and outcome shares depending on the current price:
     *         - If the market is balanced, the user will receive ETH equal to the amount of liquidity shares burned
     *         - If the market is unbalanced, the user will receive ETH and outcome shares of the least likely outcome
     * @param _shares The amount of shares to burn
     * @param _deadline The deadline to remove liquidity
     */
    function removeLiquidity(uint256 _shares, uint256 _deadline) external payable notClosed validDeadline(_deadline) {
        // Checks
        if (userToLiquidityShares[msg.sender] < _shares) {
            revert InsufficientShares();
        }

        // Effects
        (uint256 amount, uint256[] memory outcomeSharesToReturn, uint256[] memory newOutcomesShares) = marketAMM
            .getRemoveLiquidityData(
            _shares, IMarketAMM.MarketPoolState({liquidity: poolData.liquidity, outcomeShares: _getPoolShares()})
        );

        _claimFees(); // Reentrancy not possible as fees are claimed before the transfer
        _balanceFeePool(msg.sender, _shares, false);

        poolData.liquidity -= _shares;
        poolData.balance -= amount;

        userToLiquidityShares[msg.sender] -= _shares;

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            Shares storage shares = poolData.outcomes[i].shares;
            uint256 sharesToReturn = outcomeSharesToReturn[i];

            shares.total -= amount;
            shares.available = newOutcomesShares[i];
            userToOutcomeIndexToShares[msg.sender][i] += sharesToReturn;
            poolData.totalAvailableShares -= (amount + sharesToReturn);
        }

        emit LiquidityRemoved(msg.sender, _shares, amount, poolData.liquidity);

        // Interactions
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Buys shares of an outcome in the market
     * @param _amount the amount of ETH (before fees) to spend on shares
     * @param _outcomeIndex the index of the outcome to buy shares from
     * @param _minOutcomeShares the minimum amount of shares to buy
     * @param _deadline the deadline to buy shares
     */
    function buyShares(uint256 _amount, uint256 _outcomeIndex, uint256 _minOutcomeShares, uint256 _deadline)
        external
        payable
        notClosed
        matchingAmount(_amount)
        validDeadline(_deadline)
    {
        uint256 fee = _amount * fees.feeBPS / BPS;
        uint256 amountAfterFee = _amount - fee;

        (uint256 shares) = marketAMM.getBuyOutcomeData(
            amountAfterFee,
            _outcomeIndex,
            IMarketAMM.MarketPoolState({liquidity: poolData.liquidity, outcomeShares: _getPoolShares()})
        );

        if (shares < _minOutcomeShares) {
            revert MinimumSharesNotMet();
        }

        poolData.balance += amountAfterFee;
        fees.poolWeight += fee;
        fees.totalFeesCollected += fee;

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            Shares storage outcomeShares = poolData.outcomes[i].shares;
            outcomeShares.total = outcomeShares.total + amountAfterFee;
            outcomeShares.available = outcomeShares.available + amountAfterFee;
            poolData.totalAvailableShares += amountAfterFee;
        }

        userToOutcomeIndexToShares[msg.sender][_outcomeIndex] += shares;
        poolData.outcomes[_outcomeIndex].shares.available -= shares;
        poolData.totalAvailableShares -= shares;

        emit SharesBought(msg.sender, _outcomeIndex, _amount, fee, shares);
    }

    /**
     * @notice Sells shares of an outcome in the market
     * @param _receiveAmount the amount of ETH (before fee) to receive for shares
     * @param _outcomeIndex the index of the outcome to sell shares from
     * @param _maxOutcomeShares the maximum amount of shares to sell
     * @param _deadline the deadline to sell shares
     */
    function sellShares(uint256 _receiveAmount, uint256 _outcomeIndex, uint256 _maxOutcomeShares, uint256 _deadline)
        external
        payable
        notClosed
        validDeadline(_deadline)
    {
        // Checks
        (uint256 shares) = marketAMM.getSellOutcomeData(
            _receiveAmount,
            _outcomeIndex,
            IMarketAMM.MarketPoolState({liquidity: poolData.liquidity, outcomeShares: _getPoolShares()})
        );

        if (shares > _maxOutcomeShares) {
            revert MaxSharesNotMet();
        }

        if (userToOutcomeIndexToShares[msg.sender][_outcomeIndex] < shares) {
            revert InsufficientShares();
        }

        // Effects
        uint256 fee = _receiveAmount * fees.feeBPS / BPS;
        uint256 receiveAmountAfterFee = _receiveAmount - fee;

        fees.poolWeight += fee;
        fees.totalFeesCollected += fee;
        poolData.balance -= _receiveAmount;

        userToOutcomeIndexToShares[msg.sender][_outcomeIndex] -= shares;
        poolData.outcomes[_outcomeIndex].shares.available += shares;
        poolData.totalAvailableShares += shares;

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            Shares storage outcomeShares = poolData.outcomes[i].shares;
            outcomeShares.total = outcomeShares.total - _receiveAmount;
            outcomeShares.available = outcomeShares.available - _receiveAmount;
            poolData.totalAvailableShares -= _receiveAmount;
        }

        emit SharesSold(msg.sender, _outcomeIndex, receiveAmountAfterFee, fee, shares);

        // Interactions
        (bool success,) = msg.sender.call{value: receiveAmountAfterFee}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Closes the market if the close time has passed
     *         The market will be closed for trading and the outcome will be resolved after a delay
     */
    function closeMarket() external onlyAtState(MarketState.open) {
        if (info.closeTime > block.timestamp) {
            revert MarketCloseTimeNotPassed();
        }

        _setMarketState(MarketState.closed);
        info.closedAt = block.timestamp;
    }

    /**
     * @notice Resolves the market outcome index using the Oracle
     */
    function resolveMarket() external onlyAtState(MarketState.closed) {
        if (info.closedAt + resolveDelay > block.timestamp) {
            revert MarketResolveDelayNotPassed();
        }

        if (!oracle.isResolved()) {
            revert OracleNotResolved();
        }

        resolvedOutcomeIndex = oracle.getOutcome();
        _setMarketState(MarketState.resolved);
    }

    /**
     * @notice Claims the rewards for the winning outcome
     */
    function claimRewards() external payable onlyAtState(MarketState.resolved) {
        // Checks
        uint256 shares = userToOutcomeIndexToShares[msg.sender][resolvedOutcomeIndex];

        if (shares == 0) {
            revert NoRewardsToClaim();
        }

        // Effects
        userToOutcomeIndexToShares[msg.sender][resolvedOutcomeIndex] = 0;
        poolData.balance -= shares;

        emit RewardsClaimed(msg.sender, shares);

        // Interactions
        (bool success,) = msg.sender.call{value: shares}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Claims the liquidity from the market
     */
    function claimLiquidity() external payable onlyAtState(MarketState.resolved) {
        // Checks
        uint256 shares = userToLiquidityShares[msg.sender];

        if (shares == 0) {
            revert NoLiquidityToClaim();
        }

        // Effects
        _claimFees();

        (uint256 value) = marketAMM.getClaimLiquidityData(
            shares, poolData.outcomes[resolvedOutcomeIndex].shares.available, poolData.liquidity
        );
        userToLiquidityShares[msg.sender] = 0;
        poolData.balance -= value;

        emit LiquidityClaimed(msg.sender, shares);

        // Interactions
        (bool success,) = msg.sender.call{value: value}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Claims the fees from the market
     */
    function claimFees() external payable {
        _claimFees();
    }

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL VIEW
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the general information about the market
     * @return info The information of the market
     */
    function getInfo() external view returns (MarketInfo memory) {
        return info;
    }

    /**
     * @notice Getter for the pool data of the market
     * @return The poolData state variable
     */
    function getPoolData() external view returns (MarketPoolData memory) {
        return poolData;
    }

    /**
     * @notice Returns the delay after the close time, after which the market can be resolved
     */
    function getResolveDelay() external view returns (uint256) {
        return resolveDelay;
    }

    /**
     * @notice Returns the fee BPS for buying and selling shares
     * @dev The fee is calculated as feeBPS / 10000
     */
    function getFeeBPS() external view returns (uint256 feeBPS) {
        feeBPS = fees.feeBPS;
    }

    /**
     * @notice Returns the outcomes of the market
     * @return names The names of the outcomes
     * @return totalShares The total shares of the outcomes
     * @return poolShares The shares available for trading in the pool
     */
    function getOutcomes()
        external
        view
        returns (string[] memory names, uint256[] memory totalShares, uint256[] memory poolShares)
    {
        names = new string[](info.outcomeCount);
        totalShares = new uint256[](info.outcomeCount);
        poolShares = new uint256[](info.outcomeCount);

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            names[i] = poolData.outcomes[i].name;
            totalShares[i] = poolData.outcomes[i].shares.total;
            poolShares[i] = poolData.outcomes[i].shares.available;
        }
    }

    /**
     * @notice Returns the shares of the user for a specific outcome
     * @return shares of the outcome
     */
    function getUserOutcomeShares(address _user, uint256 _outcomeIndex) external view returns (uint256 shares) {
        return userToOutcomeIndexToShares[_user][_outcomeIndex];
    }

    /**
     * @notice Returns the liquidity shares of the user
     * @return shares of liquidity
     */
    function getUserLiquidityShares(address _user) external view returns (uint256 shares) {
        return userToLiquidityShares[_user];
    }

    /**
     * @notice Returns the price of an outcome
     * @param _outcomeIndex The index of the outcome to get the price of
     * @return price of the outcome
     */
    function getOutcomePrice(uint256 _outcomeIndex) external view returns (uint256 price) {
        if (state == MarketState.resolved) {
            return _outcomeIndex == resolvedOutcomeIndex ? ONE : 0;
        }

        //@changes expected args 2 given 3
        return marketAMM.getOutcomePrice(
            _outcomeIndex,
            // poolData.totalAvailableShares,
            IMarketAMM.MarketPoolState({liquidity: poolData.liquidity, outcomeShares: _getPoolShares()})
        );
    }

    /**
     * @notice Returns the outcome index of the resolved outcome
     * @return outcomeIndex The index of the resolved outcome
     */
    function getResolveOutcomeIndex() external view onlyAtState(MarketState.resolved) returns (uint256 outcomeIndex) {
        outcomeIndex = resolvedOutcomeIndex;
    }

    /**
     * @notice Returns the claimable fees of the user
     * @param _user The address of the user
     * @return amount The amount of fees claimable by the user
     */
    function getClaimableFees(address _user) public view returns (uint256 amount) {
        amount = _getClaimableFees(_user);
    }

    /**
     * @notice Returns the total fees claimed by the user
     * @param _user The address of the user
     * @return claimedFees The total fees claimed by the user
     */
    function getUserClaimedFees(address _user) external view returns (uint256 claimedFees) {
        claimedFees = fees.userClaimedFees[_user];
    }

    /*//////////////////////////////////////////////////////////////
                             PRIVATE
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Adds liquidity to the market
     * @param _user The address of the user
     * @param _amount The amount of ETH to add to the market
     */
    function _addLiquidity(address _user, uint256 _amount) private notClosed matchingAmount(_amount) {
        // Calculate the amount of liquidity shares and outcome shares to return
        (uint256 liquidityShares, uint256[] memory outcomeShareToReturn, uint256[] memory newOutcomeShares) = marketAMM
            .getAddLiquidityData(
            _amount, IMarketAMM.MarketPoolState({liquidity: poolData.liquidity, outcomeShares: _getPoolShares()})
        );

        if (poolData.liquidity > 0) {
            _balanceFeePool(_user, liquidityShares, true);
        }

        poolData.liquidity += liquidityShares;
        poolData.balance += _amount;

        userToLiquidityShares[_user] += liquidityShares;

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            Shares storage shares = poolData.outcomes[i].shares;
            uint256 sharesToReturn = outcomeShareToReturn[i];

            shares.total += _amount;
            shares.available = newOutcomeShares[i];
            userToOutcomeIndexToShares[_user][i] += sharesToReturn;
            poolData.totalAvailableShares += (_amount - sharesToReturn);
        }

        emit LiquidityAdded(_user, _amount, liquidityShares, poolData.liquidity);
    }

    /**
     * @notice A function for balancing the fee pool to ensure the correct ratio of fees for the LPs
     * @param _liquidityShares The amount of liquidity shares to add or remove
     * @param _add A boolean to determine if the liquidity is being added or removed
     */
    function _balanceFeePool(address _user, uint256 _liquidityShares, bool _add) private {
        uint256 poolShare = (_liquidityShares * fees.poolWeight) / poolData.liquidity;

        if (_add) {
            fees.poolWeight += poolShare;
            fees.userClaimedFees[_user] += poolShare;
        } else {
            fees.poolWeight -= poolShare;
            fees.userClaimedFees[_user] -= poolShare;
        }
    }

    /**
     * @notice Claims the fees of the user
     */
    function _claimFees() private {
        uint256 amount = _getClaimableFees(msg.sender);

        if (amount == 0) {
            return;
        }

        fees.userClaimedFees[msg.sender] += amount;

        emit FeesClaimed(msg.sender, amount);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @notice Sets the state of the market
     * @param _state The new state of the market
     */
    function _setMarketState(MarketState _state) private {
        state = _state;
        emit MarketStateUpdated(block.timestamp, _state);
    }

    /**
     * @notice Initializes the general information of the market
     * @param _marketInfo The general information of the market
     */
    function _initMarketInfo(MarketInfoInput calldata _marketInfo) private {
        if (_marketInfo.closeTime <= block.timestamp) {
            revert InvalidCloseTime();
        }

        if (_marketInfo.resolveDelay < MIN_RESOLVE_DELAY || _marketInfo.resolveDelay > MAX_RESOLVE_DELAY) {
            revert InvalidResolveDelay(MIN_RESOLVE_DELAY, MAX_RESOLVE_DELAY);
        }

        info.question = _marketInfo.question;
        info.closeTime = _marketInfo.closeTime;
        info.createTime = block.timestamp;
        resolveDelay = _marketInfo.resolveDelay;
    }

    /**
     * @notice Initializes the outcomes of the market
     * @param _outcomeNames The outcome names of the market
     */
    function _initOutcomes(string[] calldata _outcomeNames) private {
        if (_outcomeNames.length != 3) {
            revert OnlyThreeOutcomeMarketSupported();
        }

        info.outcomeCount = _outcomeNames.length;

        for (uint256 i = 0; i < _outcomeNames.length; ++i) {
            Shares memory shares = Shares({total: 0, available: 0});
            Outcome memory outcome = Outcome({name: _outcomeNames[i], shares: shares});
            poolData.outcomes.push(outcome);
        }
    }

    /**
     * @notice Initializes the addresses of the market
     * @param _creator The creator of the market
     * @param _oracle The oracle address, from which the outcome will be resolved
     * @param _marketAMM The MarketAMM contract used for calculations
     */
    function _initAddresses(address _creator, IOracle _oracle, IMarketAMM _marketAMM)
        private
        nonZeroAddress(_creator)
        nonZeroAddress(address(_oracle))
        nonZeroAddress(address(_marketAMM))
    {
        creator = _creator;
        oracle = _oracle;
        marketAMM = _marketAMM;
    }

    /**
     * @notice Initializes the fee basis points for buying and selling shares
     * @param _feeBPS The fee basis points for buying and selling shares
     */
    function _initFeeBPS(uint256 _feeBPS) private {
        if (_feeBPS > BPS) {
            revert InvalidFeeBPS();
        }

        fees.feeBPS = _feeBPS;
    }

    /**
     * @notice Emits the MarketInitialized event
     */
    function _emitMarketInit() private {
        emit MarketInitialized(
            info.question,
            info.outcomeCount,
            info.closeTime,
            creator,
            address(oracle),
            address(marketAMM),
            poolData.liquidity,
            resolveDelay,
            fees.feeBPS
        );
    }

    /*//////////////////////////////////////////////////////////////
                             PRIVATE VIEW
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the available shares to trade from the market pool
     * @return poolShares The available shares to trade from the market pool
     */
    function _getPoolShares() private view returns (uint256[] memory poolShares) {
        poolShares = new uint256[](info.outcomeCount);
        Outcome[] storage outcomes = poolData.outcomes;

        for (uint256 i = 0; i < info.outcomeCount; ++i) {
            poolShares[i] = outcomes[i].shares.available;
        }

        return poolShares;
    }

    /**
     * @notice Returns the claimable fees of the user
     * @param _user The address of the user
     */
    function _getClaimableFees(address _user) private view returns (uint256 amount) {
        uint256 claimed = fees.userClaimedFees[_user];
        uint256 amountToClaim = (userToLiquidityShares[_user] * fees.poolWeight) / poolData.liquidity;

        amount = claimed > amountToClaim ? 0 : amountToClaim - claimed;
    }
}
