// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IChainlinkPriceOracle} from "../interfaces/IChainlinkPriceOracle.sol";
import {IXUSD} from "../interfaces/IXUSD.sol";
import {IWETH} from "../interfaces/IWETH.sol";

import {ICredit} from "../interfaces/ICredit.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract State is ICredit, ReentrancyGuard {
    IXUSD public XUSD;
    IWETH public WETH;

    uint32 public constant oraclePrecision = 1e8;

    uint8 public constant collateralRatio = 3; // means 300%
    uint8 public constant liquidationRatio = 2; //means 200%

    uint32 public constant borrowFeePercentagePoint = 100; //means 1%
    uint32 public constant interestPercentagePoints = 500; //means 5%

    uint32 public constant liquidationPenaltyPercentagePoint = 500; //means 5% penalty for liquidation that we are take from user
    uint32 public constant liquidationBonusPercentagePoint = 1000; //means 10%, the bonus that liquidator get for liquidation

    uint32 public constant precisionMultiplier = 1e4;

    mapping(address token => uint256) public accumulatedPenalties; //penalties from liquidation measured in XFI
    uint256 public accumulatedFees = 0; // fees from interest and borrow fee measured in XUSD

    address[] private _collateralTokens;

    uint256 ray = 1e27;

    mapping(address token => address oracle) public priceFeeds;

    mapping(address user => Position) public positions; //opened positions right now
}
