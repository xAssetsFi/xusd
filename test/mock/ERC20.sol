// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("mock", "mock") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
