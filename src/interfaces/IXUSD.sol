// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IXUSD is IERC20Metadata {
    function mint(address to, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function setMaxAmountToMint(uint value) external;
}
