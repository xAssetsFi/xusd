// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IChainlinkPriceOracle {
    function latestAnswer() external view returns (int256);
}
