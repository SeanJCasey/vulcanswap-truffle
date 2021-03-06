pragma solidity 0.5.8;

import "../../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract SeanToken is ERC20 {
    string public name = "SeanToken";
    string public symbol = "SJC";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 10000 * (10 ** decimals);

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
