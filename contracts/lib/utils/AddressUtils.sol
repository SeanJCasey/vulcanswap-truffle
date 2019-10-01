pragma solidity 0.5.8;

library AddressUtils {
    function castPayable(address self)
        pure
        internal
        returns (address payable)
    {
        return address(uint160(self));
    }
}
