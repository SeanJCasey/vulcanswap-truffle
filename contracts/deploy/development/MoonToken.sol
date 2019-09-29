pragma solidity ^0.5.2;

import "../../../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MoonToken is ERC20 {
    string public name = "Moon Unit";
    string public symbol = "MNU";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 10000 * (10 ** decimals);

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
