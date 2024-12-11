// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address receiver,
        uint256 deadline
    ) external;

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) external view returns (uint[] memory amounts);
}
