pragma solidity 0.5.8;

// import '../../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol';
// import '../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';

contract LimitedAcceptedCurrencies {
    address[] internal acceptedCurrencies;

    enum AcceptedCurrencyState { None, Active, Inactive }

    struct AcceptedCurrencyInfo {
        uint256 minAmount;
        uint256 maxAmount;
        AcceptedCurrencyState state;
    }
    mapping(address => AcceptedCurrencyInfo) public acceptedCurrencyInfo;

    modifier acceptedCurrencyExists(address _currency, bool _exists) {
        if(_exists) {
            require(acceptedCurrencyInfo[_currency].state != AcceptedCurrencyState.None);
        }
        else {
            require(acceptedCurrencyInfo[_currency].state == AcceptedCurrencyState.None);
        }
        _;
    }

    modifier currencyIsAccepted(address _currency) {
        require(acceptedCurrencyInfo[_currency].state == AcceptedCurrencyState.Active);
        _;
    }

    function addAcceptedCurrency(
        address _currency,
        uint256 _minAmount,
        uint256 _maxAmount
    )
        internal
        acceptedCurrencyExists(_currency, false)
    {
        AcceptedCurrencyInfo memory acceptedCurrency = AcceptedCurrencyInfo({
            minAmount: _minAmount,
            maxAmount: _maxAmount,
            state: AcceptedCurrencyState.Active
        });
        acceptedCurrencyInfo[_currency] = acceptedCurrency;
        acceptedCurrencies.push(_currency);
    }

    function updateAcceptedCurrencyIsActive(
        address _currency,
        bool _isActive
    )
        internal
        acceptedCurrencyExists(_currency, true)
    {
        AcceptedCurrencyInfo storage acceptedCurrency = acceptedCurrencyInfo[_currency];
        acceptedCurrency.state = _isActive ? AcceptedCurrencyState.Active : AcceptedCurrencyState.Inactive;
    }

    function updateAcceptedCurrencyLimits(
        address _currency,
        uint256 _minAmount,
        uint256 _maxAmount
    )
        internal
        acceptedCurrencyExists(_currency, true)
    {
        AcceptedCurrencyInfo storage acceptedCurrency = acceptedCurrencyInfo[_currency];
        acceptedCurrency.minAmount = _minAmount;
        acceptedCurrency.maxAmount = _maxAmount;
    }

    function getAcceptedCurrencyLimits(address _currency)
        view
        public
        acceptedCurrencyExists(_currency, true)
        returns (uint256 minAmount_, uint256 maxAmount_)
    {
        AcceptedCurrencyInfo memory acceptedCurrency = acceptedCurrencyInfo[_currency];
        return (acceptedCurrency.minAmount, acceptedCurrency.maxAmount);
    }
}
