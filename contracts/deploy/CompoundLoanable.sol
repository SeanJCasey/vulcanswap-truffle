pragma solidity 0.5.8;

import '../../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';
import '../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
import '../lib/Compound/CErc20Interface.sol';
import '../lib/Compound/CEtherInterface.sol';

// Owned by our contract
contract CompoundLoanable {
    using SafeMath for uint256;

    struct CompoundLoan {
        uint256 balanceCTokens;
        uint256 balanceUnderlying;
        address underlying;
    }
    mapping(uint256 => CompoundLoan) internal idToCompoundLoan;
    mapping(address => address) internal underlyingToCToken;

    function castAddressPayable(address _address)
        pure
        private
        returns (address payable)
    {
        return address(uint160(_address));
    }

    function compoundCloseLoan(uint256 _id)
        internal
        returns (uint256 cTokensRemaining_, address cTokenAddress_)
    {
        CompoundLoan memory loan = idToCompoundLoan[_id];

        // Only run when balance underlying is depleted
        assert(loan.balanceUnderlying == 0);

        // Copy remaining cToken address and balance
        cTokensRemaining_ = loan.balanceCTokens;
        cTokenAddress_ = underlyingToCToken[loan.underlying];

        // Clear storage
        delete idToCompoundLoan[_id];
    }

    // TODO - remove
    // function getCompoundLoan(uint256 _id)
    //     view
    //     external
    //     returns (uint256 balanceUnderlying_, address underlying_)
    // {
    //     CompoundLoan memory loan = idToCompoundLoan[_id];
    //     return (loan.balanceUnderlying, loan.underlying);
    // }

    function compoundRedeemBalanceUnderlying(uint256 _id)
        internal
        returns (uint256 redeemAmount_)
    {
        uint256 redeemAmount = idToCompoundLoan[_id].balanceUnderlying;

        if (redeemAmount > 0) {
            compoundRedeemUnderlying(_id, redeemAmount);
        }
        return redeemAmount;
    }

    function compoundRedeemUnderlying(uint256 _id, uint256 _amount) internal {
        CompoundLoan storage loan = idToCompoundLoan[_id];
        require(
            loan.balanceUnderlying >= _amount,
            "Compound redeem: amount greater than balance"
        );

        // Can use CErc20 for CEther because interface function is the same.
        CErc20Interface cToken = CErc20Interface(underlyingToCToken[loan.underlying]);

        // Redeem cTokens and adjust the underlying and cToken balances.
        loan.balanceUnderlying = loan.balanceUnderlying.sub(_amount);
        uint256 cTokenBalanceBefore = cToken.balanceOf(address(this));
        require(
            cToken.redeemUnderlying(_amount) == 0,
            "Compound redeem: redeem failed"
        );
        uint256 cTokenBalanceAfter = cToken.balanceOf(address(this));
        loan.balanceCTokens = loan.balanceCTokens.sub(cTokenBalanceBefore.sub(cTokenBalanceAfter));
    }

    function compoundSupplyPrincipal(uint256 _id) private {
        CompoundLoan storage loan = idToCompoundLoan[_id];

        uint256 amountSupplied;
        if (loan.underlying == address(0)) {
            amountSupplied = compoundSupplyEther(loan.balanceUnderlying);
        }
        else {
            amountSupplied = compoundSupplyToken(
                loan.balanceUnderlying,
                IERC20(loan.underlying)
            );
        }
        loan.balanceCTokens = amountSupplied;
    }

    function compoundSupplyEther(uint256 _amount)
        private
        returns (uint256 amountSupplied_)
    {
        address payable cEtherAddress = castAddressPayable(
            underlyingToCToken[address(0)]
        );
        CEtherInterface cEther = CEtherInterface(cEtherAddress);

        uint256 balanceBefore = cEther.balanceOf(address(this));
        cEther.mint.value(_amount)();
        uint256 balanceAfter = cEther.balanceOf(address(this));

        amountSupplied_ = balanceAfter.sub(balanceBefore);
    }

    function compoundSupplyToken(uint256 _amount, IERC20 _underlying)
        private
        returns (uint256 amountSupplied_)
    {
        address cTokenAddress = underlyingToCToken[address(_underlying)];
        CErc20Interface cToken = CErc20Interface(cTokenAddress);

        _underlying.approve(cTokenAddress, _amount);

        uint256 balanceBefore = cToken.balanceOf(address(this));
        require(cToken.mint(_amount) == 0, "Compound mint: failed");
        uint256 balanceAfter = cToken.balanceOf(address(this));

        amountSupplied_ = balanceAfter.sub(balanceBefore);
    }

    function createCompoundLoan(
        uint256 _id,
        uint256 _amount,
        address _underlying
    )
        internal
    {
        require (
            underlyingToCToken[_underlying] != address(0),
            "Compound loan create: no cToken address found"
        );

        CompoundLoan memory loan = CompoundLoan({
            balanceCTokens: 0,
            balanceUnderlying: _amount,
            underlying: _underlying
        });
        idToCompoundLoan[_id] = loan;

        compoundSupplyPrincipal(_id);
    }
}
