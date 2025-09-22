// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestTokenB is ERC20 {
    constructor() ERC20("Test Token B", "TTB") {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}