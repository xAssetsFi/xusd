// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IChainlinkPriceOracle} from "src/interfaces/IChainlinkPriceOracle.sol";

contract Oracle is IChainlinkPriceOracle {
    int256 public answer;

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function latestAnswer() external view returns (int256) {
        return answer;
    }
}
