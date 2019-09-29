pragma solidity 0.5.8;

import '../../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';
import '../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol';
import '../lib/Compound/CErc20Interface.sol';
import '../lib/Compound/CEtherInterface.sol';

// Owned by our contract
contract CompoundLoanable {
    using SafeMath for uint256;

    struct CompoundLoan {
        uint256 balanceUnderlying;
        address underlying;
    }
    mapping(uint256 => CompoundLoan) internal idToCompoundLoan;
    mapping(address => address) internal underlyingToCToken;

    function castAddressPayable(address _address)
        pure
        internal
        returns (address payable)
    {
        return address(uint160(_address));
    }

    // function compoundSelfDestruct(uint256 _id) internal returns (uint256 cTokensRemaining_) {
    //     CompoundLoan storage loan = idToCompoundLoan[_id];

    //     // Redeem remaining underlying
    //     if (loan.balanceUnderlying > 0) {
    //         uint256 redeemAmount = loan.balanceUnderlying;
    //         loan.balanceUnderlying = 0;
    //         compoundRedeemUnderlying(_id, redeemAmount);
    //     }

    //     // Return remaining cTokens
    //     cTokensRemaining_ = loan.cToken.balanceOf(address(this));

    //     // TODO: Is this the right way to empty struct storage?
    //     loan = CompoundLoan();
    // }

    // function testCompoundRedeemCall(uint256 _id, uint256 _amount) view external returns (uint256) {
    //     return testCompoundRedeem(_id, _amount).call();
    // }

    // function testCompoundRedeem(uint256 _id, uint256 _amount) public returns (uint256) {
    //     CompoundLoan storage loan = idToCompoundLoan[_id];
    //     require(
    //         loan.balanceUnderlying >= _amount,
    //         "Compound redeem: amount greater than balance"
    //     );

    //     loan.balanceUnderlying = loan.balanceUnderlying.sub(_amount);

    //     if (loan.underlying == address(0)) {
    //         // Can use CErc20 for CEther because interface function is the same.
    //         address payable cEtherAddress = castAddressPayable(underlyingToCToken[loan.underlying]);
    //         require(
    //             CEtherInterface(cEtherAddress).redeemUnderlying(_amount) == 0,
    //             "Compound redeem: redeem failed"
    //         );
    //     }
    //     else {
    //         // Can use CErc20 for CEther because interface function is the same.
    //         address cTokenAddress = underlyingToCToken[loan.underlying];
    //         require(
    //             CErc20Interface(cTokenAddress).redeemUnderlying(_amount) == 0,
    //             "Compound redeem: redeem failed"
    //         );
    //     }
    // }

    // TODO - remove
    function getCompoundLoan(uint256 _id) view external returns (uint256 balanceUnderlying_, address underlying_) {
        CompoundLoan memory loan = idToCompoundLoan[_id];
        return (loan.balanceUnderlying, loan.underlying);
    }

    function compoundRedeemUnderlying(uint256 _id, uint256 _amount) internal {
        CompoundLoan storage loan = idToCompoundLoan[_id];
        require(
            loan.balanceUnderlying >= _amount,
            "Compound redeem: amount greater than balance"
        );

        // Can use CErc20 for CEther because interface function is the same.
        address cTokenAddress = underlyingToCToken[loan.underlying];
        loan.balanceUnderlying = loan.balanceUnderlying.sub(_amount);
        require(
            CErc20Interface(cTokenAddress).redeemUnderlying(_amount) == 0,
            "Compound redeem: redeem failed"
        );

        // if (loan.underlying == address(0)) {
        //     // Can use CErc20 for CEther because interface function is the same.
        //     address payable cEtherAddress = castAddressPayable(underlyingToCToken[loan.underlying]);
        //     require(
        //         CEtherInterface(cEtherAddress).redeemUnderlying(_amount) == 0,
        //         "Compound redeem: redeem failed"
        //     );
        // }
    }

    function compoundSupplyPrincipal(uint256 _id) private {
        CompoundLoan memory loan = idToCompoundLoan[_id];

        if (loan.underlying == address(0)) {
            compoundSupplyEther(loan.balanceUnderlying);
        }
        else {
            compoundSupplyToken(loan.balanceUnderlying, IERC20(loan.underlying));
        }
    }

    function compoundSupplyEther(uint256 _amount) private {
        address payable cEtherAddress = castAddressPayable(underlyingToCToken[address(0)]);
        CEtherInterface cEther = CEtherInterface(cEtherAddress);

        cEther.mint.value(_amount)();
    }

    function compoundSupplyToken(uint256 _amount, IERC20 _underlying) private {
        address cTokenAddress = underlyingToCToken[address(_underlying)];
        CErc20Interface cToken = CErc20Interface(cTokenAddress);

        _underlying.approve(cTokenAddress, _amount);
        require(cToken.mint(_amount) == 0, "Compound mint: failed");
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
            balanceUnderlying: _amount,
            underlying: _underlying
        });
        idToCompoundLoan[_id] = loan;

        compoundSupplyPrincipal(_id);
    }
}
