pragma solidity 0.5.8;

import "../../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract FakeDai is ERC20 {
    string public name = "Fake Dai";
    string public symbol = "fDAI";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 1000000 * (10 ** decimals);

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
