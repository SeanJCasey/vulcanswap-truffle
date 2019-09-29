pragma solidity 0.5.8;

import '../../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol';
import '../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
import '../../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';
import './CompoundLoanable.sol';
import './UniswapFactoryInterface.sol';
import './UniswapExchangeInterface.sol';

contract CostAverageOrderBook is Ownable, CompoundLoanable {
    using SafeMath for uint256;

    uint256 public nextId;
    uint256 private feeBalance;
    uint256 private feesWithdrawn;
    uint32 public minFrequency;
    uint8 public minBatches;
    uint8 public maxBatches;

    UniswapFactoryInterface internal factory;

    enum OrderState { Failed, InProgress, Completed, Cancelled }

    struct OrderInfo {
        address account;
        address sourceCurrency;
        address targetCurrency;
        OrderState state;
        uint256 amount;
        uint256 frequency; // in seconds
        uint256 lastConversionTimestamp;
        uint256 sourceCurrencyBalance;
        uint256 targetCurrencyConverted;
        uint8 batches;
        uint8 batchesExecuted;
    }
    mapping(uint256 => OrderInfo) public idToCostAverageOrder;
    mapping(address => uint256[]) public accountToOrderIds;
    mapping(address => uint256) public sourceCurrencyToMinAmount;
    mapping(address => uint256) public sourceCurrencyToMaxAmount;
    mapping(address => uint256) public currencyToFeeBalance;
    mapping(address => uint256) public currencyToFeesWithdrawn;

    event NewOrder(
        address indexed _account,
        uint256 _orderId
    );

    event OrderConversion(
        address indexed _account,
        uint256 _orderId
    );

    event CancelOrder(
        address indexed _account,
        uint256 _orderId
    );

    event CompleteOrder(
        address indexed _account,
        uint256 _orderId
    );

    constructor(address _uniswapFactoryAddress) public {
        factory = UniswapFactoryInterface(_uniswapFactoryAddress);
        nextId = 1; // Set first order as 1 instead of 0

        // Initial order min/max
        maxBatches = 255;
        minBatches = 1;
        minFrequency = 1 hours;
    }

    // Compound needs to be able to pay back Eth loans
    function() external payable { require(msg.data.length == 0); }

    // A max amount of 0 means the token is not accepted as source currency.
    function updateSourceCurrency(
        address _sourceCurrency,
        uint256 _minAmount,
        uint256 _maxAmount,
        address _cToken
    )
        external
        onlyOwner
    {
        sourceCurrencyToMinAmount[_sourceCurrency] = _minAmount;
        sourceCurrencyToMaxAmount[_sourceCurrency] = _maxAmount;
        underlyingToCToken[_sourceCurrency] = _cToken;
    }

    function getSourceCurrencyLimits(address _sourceCurrency)
        external
        view
        returns (uint256 minAmount_, uint256 maxAmount_)
    {
        minAmount_ = sourceCurrencyToMinAmount[_sourceCurrency];
        maxAmount_ = sourceCurrencyToMaxAmount[_sourceCurrency];
    }

    // TODO
    // function getFeesCollectedTotals()
    //     view
    //     external
    //     returns (uint256[] memory fees_)
    // {

    // }

    function closeLoan(uint256 _id) private {
        if (idToCompoundLoan[_id].balanceCTokens > 0) {
            // Delete loan and add leftover cTokens to fee
            (uint256 cTokensRemaining, address cTokenAddress) = compoundCloseLoan(_id);
            currencyToFeeBalance[cTokenAddress].add(cTokensRemaining);
        }
    }

    function completeOrder(uint256 _id) private {
        OrderInfo storage order = idToCostAverageOrder[_id];

        closeLoan(_id);
        order.state = OrderState.Completed;

        emit CompleteOrder(order.account, _id);
    }

    function cancelOrder(uint256 _id) public {
        OrderInfo storage order = idToCostAverageOrder[_id];

        require(order.account == msg.sender);
        require(order.sourceCurrencyBalance > 0);

        uint256 refundAmount = order.sourceCurrencyBalance;
        order.sourceCurrencyBalance = 0;

        if (idToCompoundLoan[_id].balanceUnderlying > 0) {
            // Transfer remaining loaned tokens back to owner
            uint256 redeemAmount = compoundRedeemBalanceUnderlying(_id);
            assert(redeemAmount == refundAmount);
        }

        if (order.sourceCurrency == address(0)) {
            msg.sender.transfer(refundAmount);
        }
        else {
            IERC20(order.sourceCurrency).transfer(order.account, refundAmount);
        }

        closeLoan(_id);
        order.state = OrderState.Cancelled;

        emit CancelOrder(order.account, _id);
    }

    function createOrder(
        uint256 _amount,
        address _sourceCurrency,
        address _targetCurrency,
        uint256 _frequency,
        uint8 _batches
    )
        public
        payable
        returns (uint256 id_)
    {
        // Enforce common min/max values
        require(_batches <= maxBatches);
        require(_batches >= minBatches);
        require(_frequency >= minFrequency);

        uint256 orderId;
        if (_sourceCurrency == address(0)) {
            orderId = createOrderEth(
                _amount,
                _targetCurrency,
                _frequency,
                _batches
            );
        }
        else {
            orderId = createOrderToken(
                _amount,
                _sourceCurrency,
                _targetCurrency,
                _frequency,
                _batches
            );
        }
        accountToOrderIds[msg.sender].push(orderId);

        // Loan source currency on Compound if possible
        if (underlyingToCToken[_sourceCurrency] != address(0)) {
            createCompoundLoan(orderId, _amount, _sourceCurrency);
        }

        emit NewOrder(msg.sender, orderId);

        return orderId;
    }

    function createOrderEth(
        uint256 _amount,
        address _targetCurrency,
        uint256 _frequency,
        uint8 _batches
    )
        internal
        returns (uint256 id_)
    {
        require(_amount == msg.value); // should not be sending ETH
        require(_targetCurrency != address(0)); // target can't be ETH
        require(_amount >= sourceCurrencyToMinAmount[address(0)]);

        OrderInfo memory newOrder = OrderInfo({
            amount: _amount,
            sourceCurrency: address(0),
            targetCurrency: _targetCurrency,
            state: OrderState.InProgress,
            frequency: _frequency,
            batches: _batches,
            account: msg.sender,
            sourceCurrencyBalance: _amount,
            targetCurrencyConverted: 0,
            batchesExecuted: 0,
            lastConversionTimestamp: 0
        });

        idToCostAverageOrder[nextId] = newOrder;
        nextId++;
        return nextId-1;
    }

    function createOrderToken(
        uint256 _amount,
        address _sourceCurrency,
        address _targetCurrency,
        uint256 _frequency,
        uint8 _batches
    )
        internal
        returns (uint256 id_)
    {
        // Validate inputs
        require(msg.value == 0); // Not payable
        require(_targetCurrency != _sourceCurrency); // source and target can't be same token
        require(_amount >= sourceCurrencyToMinAmount[_sourceCurrency]);

        // Transfer tokens to contract
        IERC20(_sourceCurrency).transferFrom(msg.sender, address(this), _amount);

        // Create order
        OrderInfo memory newOrder = OrderInfo({
            amount: _amount,
            sourceCurrency: _sourceCurrency,
            targetCurrency: _targetCurrency,
            state: OrderState.InProgress,
            frequency: _frequency,
            batches: _batches,
            account: msg.sender,
            sourceCurrencyBalance: _amount,
            targetCurrencyConverted: 0,
            batchesExecuted: 0,
            lastConversionTimestamp: 0
        });
        idToCostAverageOrder[nextId] = newOrder;

        // Increment next order id
        nextId++;
        return nextId-1;
    }

    function getFeeBalance()
        view
        public
        onlyOwner
        returns (uint256 feeBalance_)
    {
        feeBalance_ = feeBalance;
    }

    function getOrder(uint256 _id)
        view
        public
        returns (
            uint256 id_,
            uint256 amount_,
            address sourceCurrency_,
            address targetCurrency_,
            OrderState state_,
            uint256 frequency_,
            uint8 batches_,
            uint8 batchesExecuted_,
            uint256 lastConversionTimestamp_,
            uint256 targetCurrencyConverted_,
            uint256 sourceCurrencyBalance_
        )
    {
        OrderInfo memory order = idToCostAverageOrder[_id];

        return (
            _id,
            order.amount,
            order.sourceCurrency,
            order.targetCurrency,
            order.state,
            order.frequency,
            order.batches,
            order.batchesExecuted,
            order.lastConversionTimestamp,
            order.targetCurrencyConverted,
            order.sourceCurrencyBalance
        );
    }

    function getOrderCount() view public returns (uint256) {
        return nextId-1;
    }

    function getOrderCountForAccount(address _account)
        view
        public
        returns (uint256 count_)
    {
        return accountToOrderIds[_account].length;
    }

    function getOrderForAccountIndex(address _account, uint256 _index)
        view
        public
        returns (
            uint256 id_,
            uint256 amount_,
            address sourceCurrency_,
            address targetCurrency_,
            OrderState state_,
            uint256 frequency_,
            uint8 batches_,
            uint8 batchesExecuted_,
            uint256 lastConversionTimestamp_,
            uint256 targetCurrencyConverted_,
            uint256 sourceCurrencyBalance_
        )
    {
        require(_index < getOrderCountForAccount(_account));

        return getOrder(accountToOrderIds[_account][_index]);
    }

    function getOrderParamLimits()
        view
        public
        returns (
            uint32 minFrequency_,
            uint8 minBatches_,
            uint8 maxBatches_
        )
    {
        return (minFrequency, minBatches, maxBatches);
    }

    // Convenience function for dapp display of contract stats
    // function getStatTotals()
    //     view
    //     external
    //     returns (
    //         uint256 orders_,
    //         uint256 conversions_,
    //         uint256 managedEth_
    //     )
    // {
    //     orders_ = getOrderCount();

    //     conversions_ = 0;
    //     for (uint256 i=1; i<=getOrderCount(); i++) {
    //         OrderInfo memory order = idToCostAverageOrder[i];
    //         conversions_ += order.batchesExecuted;
    //     }

    //     managedEth_ = address(this).balance.sub(feeBalance);
    // }

    function setMaxBatches(uint8 _maxBatches) public onlyOwner {
        maxBatches = _maxBatches;
    }

    function setMinBatches(uint8 _minBatches) public onlyOwner {
        minBatches = _minBatches;
    }

    function setMinFrequency(uint32 _minFrequency) public onlyOwner {
        minFrequency = _minFrequency;
    }

    function withdrawFees() public onlyOwner {
        require (feeBalance > 0);

        uint256 withdrawalAmount = feeBalance;
        feeBalance = 0;
        feesWithdrawn.add(withdrawalAmount);

        msg.sender.transfer(withdrawalAmount);
    }


    /*** Uniswap conversion logic ***/

    function checkConversionDue(uint256 _id) view public returns (bool) {
        OrderInfo memory order = idToCostAverageOrder[_id];

        // Check if there is a balance of source currency
        if (order.sourceCurrencyBalance <= 0) return false;

        // Check if there should be batches remaining
        if (order.batchesExecuted >= order.batches) return false;

        // Check if the first conversion has been executed
        if (order.lastConversionTimestamp == 0) return true;

        // Check if enough time has elapsed to execute the next conversion
        uint256 timeDelta = now - order.lastConversionTimestamp;
        if (timeDelta < order.frequency) return false;

        return true;
    }

    function checkConversionDueAll()
        view
        external
        returns (uint256[] memory)
    {
        uint256 totalOrderCount = getOrderCount();
        require(totalOrderCount > 0);

        uint256[] memory coversionDueMap = new uint256[](totalOrderCount);

        for (uint256 i=1; i<=totalOrderCount; i++) {
            if (checkConversionDue(i) == true) coversionDueMap[i-1] = i;
        }

        return coversionDueMap;
    }

    function checkConversionDueBatch(uint256 _idStart, uint16 _count)
        view
        external
        returns (uint256[] memory)
    {
        uint256 totalOrderCount = getOrderCount();
        require(_idStart > 0);
        require(_idStart <= totalOrderCount);

        uint256[] memory coversionDueMap = new uint256[](_count);

        for (
            uint256 i=0; i<_count && _idStart.add(i) <= totalOrderCount; i++
        )
        {
            if (checkConversionDue(_idStart.add(i)) == true) {
                coversionDueMap[i] = _idStart.add(i);
            }
        }

        return coversionDueMap;
    }

    function convertCurrency(uint256 _id) private {
        OrderInfo storage order = idToCostAverageOrder[_id];

        uint256 batchValue = valuePerBatch(order.amount, order.batches);

        // In case batchValue is more than balance, use the remainder
        if (order.sourceCurrencyBalance < batchValue) {
            batchValue = order.sourceCurrencyBalance;
        }

        // Update all values possible before performing conversion
        order.sourceCurrencyBalance -= batchValue;
        order.batchesExecuted += 1;
        order.lastConversionTimestamp = now;

        // If source currency lent on Compound, redeem amount for order
        if (idToCompoundLoan[_id].balanceUnderlying > 0) {
            compoundRedeemUnderlying(_id, batchValue);
        }

        uint256 amountReceived;
        if (order.targetCurrency == address(0)) {
            amountReceived = exchangeTokenToEth(
                order.account,
                order.sourceCurrency,
                batchValue
            );
        }
        else {
            amountReceived = exchangeEthToToken(
                order.account,
                order.targetCurrency,
                batchValue
            );
        }
        // else {
        //     amountReceived = exchangeTokenToToken(
        //         order.account,
        //         order.sourceCurrency,
        //         order.targetCurrency,
        //         batchValue
        //     );
        // }

        // Update total tokens converted
        order.targetCurrencyConverted += amountReceived;

        emit OrderConversion(order.account, _id);

        if (order.sourceCurrencyBalance == 0) {
            completeOrder(_id);
        }
    }

    function exchangeEthToToken(
        address _recipient,
        address _targetCurrency,
        uint256 _amountSourceCurrency
    )
        private
        returns (uint256 amountReceived_)
    {
        // Set up the Uniswap exchange interface for the target token
        address exchangeAddress = factory.getExchange(_targetCurrency);
        UniswapExchangeInterface exchange = UniswapExchangeInterface(exchangeAddress);

        uint256 min_tokens = 1; // TODO: implement this correctly
        uint256 deadline = now + 300; // this is the value in the docs
        amountReceived_ = exchange.ethToTokenTransferInput.value(
            _amountSourceCurrency
        )
        (
            min_tokens,
            deadline,
            _recipient
        );
    }

    function exchangeTokenToEth(
        address _recipient,
        address _sourceCurrency,
        uint256 _amountSourceCurrency
    )
        private
        returns (uint256 amountReceived_)
    {
        // Set up the Uniswap exchange interface for the target token
        address exchangeAddress = factory.getExchange(_sourceCurrency);
        UniswapExchangeInterface exchange = UniswapExchangeInterface(exchangeAddress);

        uint256 min_eth = 1; // TODO: implement this correctly
        uint256 deadline = now + 300; // this is the value in the docs

        // Approve token transfer and execute swap
        IERC20(_sourceCurrency).approve(exchangeAddress, _amountSourceCurrency);
        amountReceived_ = exchange.tokenToEthTransferInput(
            _amountSourceCurrency,
            min_eth,
            deadline,
            _recipient
        );
    }

    // function exchangeTokenToToken(
    //     address _recipient,
    //     address _sourceCurrency,
    //     address _targetCurrency,
    //     uint256 _amountSourceCurrency
    // )
    //     private
    //     returns (uint256 amountReceived_)
    // {
    //     // Set up the Uniswap exchange interface for the target token
    //     address exchangeAddress = factory.getExchange(_targetCurrency);
    //     UniswapExchangeInterface exchange = UniswapExchangeInterface(exchangeAddress);

    //     uint256 min_eth = 1; // TODO: implement this correctly
    //     uint256 deadline = now + 300; // this is the value in the docs

    //     // Approve token transfer and execute swap
    //     IERC20(_sourceCurrency).approve(exchangeAddress, _amountSourceCurrency);
    //     amountReceived_ = exchange.tokenToTokenTransferInput(
    //         _amountSourceCurrency,
    //         min_tokens,
    //         deadline,
    //         _recipient
    //     );
    // }

    // Execute converstions 1-by-1
    function executeDueConversion(uint256 _id) public {
        if (checkConversionDue(_id) == true) {
            convertCurrency(_id);
        }
    }

    // Execute conversions en masse
    function executeDueConversions() external {
        for (uint256 i=1; i<=getOrderCount(); i++) {
            executeDueConversion(i);
        }
    }

    function valuePerBatch(uint256 _amount, uint8 _batches)
        pure
        internal
        returns (uint256)
    {
        return _amount.div(_batches);
    }
}
