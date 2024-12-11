// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {State} from "./State.sol";
import {IChainlinkPriceOracle} from "../interfaces/IChainlinkPriceOracle.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {console} from "forge-std/console.sol";

abstract contract Utils is State {
    using SafeERC20 for IERC20;

    function _calculateTotalInterest(
        Position storage position
    ) internal view returns (uint112) {
        return
            uint112(
                position.interest +
                    _calculateAccruedInterest(
                        position.body,
                        position.lastUpdateTime
                    )
            );
    }

    ///@dev function calculates interest from lastUpdateTime to current time
    function _calculateAccruedInterest(
        uint body,
        uint lastUpdateTime
    ) internal view returns (uint) {
        uint interest = (((block.timestamp - lastUpdateTime) * body) *
            interestPercentagePoints) / (uint(precisionMultiplier) * 365 days);
        return interest;
    }

    function _calculateLiquidationPrice(
        uint amountXUSD,
        uint collateralAmount
    ) internal pure returns (uint64) {
        return
            uint64(
                (liquidationRatio * oraclePrecision * amountXUSD) /
                    collateralAmount
            );
    }

    function _calculateHealthFactor(
        Position storage position
    ) internal view returns (uint256 healthFactorInRay) {
        uint256 totalUsdCollateralValueInRay = 0;
        for (uint i = 0; i < position.collaterals.length; i++) {
            uint256 collateralAmountInRay = (position.collaterals[i].amount *
                ray) /
                (10 **
                    IERC20Metadata(position.collaterals[i].token).decimals());

            uint256 collateralPrice = uint256(
                getPriceFeeds(position.collaterals[i].token)
            );

            totalUsdCollateralValueInRay +=
                (collateralAmountInRay * collateralPrice) /
                oraclePrecision;
        }

        uint256 totalDebtInRay = (((position.body +
            position.borrowFee +
            _calculateTotalInterest(position)) * ray) / 1e18); // 1e18 because xusd has 18 decimals

        healthFactorInRay =
            (ray * totalUsdCollateralValueInRay) /
            (totalDebtInRay * liquidationRatio);
    }

    function _withdrawAssets(
        address token,
        address receiver,
        uint256 amount,
        bool toUnwrap
    ) internal {
        if (token == address(WETH) && toUnwrap) {
            WETH.withdraw(amount);
            _transferEth(receiver, amount);
        } else {
            IERC20(token).safeTransfer(receiver, amount);
        }
    }

    function _transferEth(address receiver, uint256 amount) internal {
        (bool success, ) = payable(receiver).call{value: amount}("");
        if (!success) revert LowLevelEthTransferFailed();
    }

    function _decreaseCollateral(
        Position storage position,
        address token,
        uint256 amount
    ) internal {
        for (uint i = 0; i < position.collaterals.length; i++) {
            if (position.collaterals[i].token != token) continue;

            if (position.collaterals[i].amount < amount)
                revert NotEnoughCollateral(
                    amount,
                    position.collaterals[i].amount
                );

            position.collaterals[i].amount -= amount;
            break;
        }
    }

    // function _removeZeroCollaterals(
    //     Position storage position
    // ) internal returns (Position storage) {
    //     uint256 length = 0;
    //     for (uint i = 0; i < position.collaterals.length; i++) {
    //         if (position.collaterals[i].amount != 0) length++;
    //     }

    //     CollateralData[] memory newCollaterals = new CollateralData[](length);

    //     length = 0;

    //     for (uint i = 0; i < position.collaterals.length; i++) {
    //         if (position.collaterals[i].amount != 0)
    //             newCollaterals[length++] = position.collaterals[i];
    //     }

    //     position.collaterals = newCollaterals;

    //     return position;
    // }

    /* ======== VIEW ======== */

    ///@notice that the function returns total debt at the current time and when you send the transaction to repay the loan you should consider it
    function getTotalDebt(
        address user
    ) public view initializedPosition(user) returns (uint) {
        Position storage position = positions[user];

        return
            position.body +
            position.borrowFee +
            _calculateTotalInterest(position);
    }

    function getPosition(
        address user
    ) external view initializedPosition(user) returns (Position memory) {
        return positions[user];
    }

    ///@dev need to change logic of this function if oracle will be different
    function getPriceFeeds(
        address token
    ) public view virtual isCollateral(token) returns (int price) {
        IChainlinkPriceOracle oracle = IChainlinkPriceOracle(priceFeeds[token]);
        return oracle.latestAnswer();
    }

    function getHealthFactor(
        address user
    ) external view initializedPosition(user) returns (uint256) {
        return _calculateHealthFactor(positions[user]);
    }

    modifier isCollateral(address token) {
        if (priceFeeds[token] == address(0)) revert NotAllowedCollateral();
        _;
    }

    modifier initializedPosition(address user) {
        if (!positions[user].isInitialized) revert PositionNotExists();
        _;
    }

    receive() external payable {}
}
