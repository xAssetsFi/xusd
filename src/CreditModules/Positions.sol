// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Utils} from "./Utils.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console2} from "forge-std/console2.sol";

abstract contract Positions is Utils {
    using SafeERC20 for IERC20;

    function _createNewPosition(
        address positionOwner,
        address token,
        uint collateralAmount,
        uint body
    ) internal {
        uint112 _borrowFee = uint112(
            (body * borrowFeePercentagePoint) / precisionMultiplier
        );
        Position storage position = positions[positionOwner];

        position.isInitialized = true;
        position.lastUpdateTime = uint32(block.timestamp);
        position.collaterals.push(CollateralData(token, collateralAmount));
        position.interest = 0;
        position.borrowFee = _borrowFee;
        position.body = body;

        uint healthFactor = _calculateHealthFactor(position);
        if (healthFactor < ray) revert HealthFactorTooLow(healthFactor);
        XUSD.mint(positionOwner, body);

        emit PositionCreated(
            positionOwner,
            position.collaterals,
            body,
            _borrowFee,
            healthFactor
        );
    }

    ///@dev we update interest every time when we update position
    function _updatePosition(
        address positionOwner,
        CollateralData[] storage collaterals,
        uint256 newBody,
        uint112 newInterest,
        uint112 newBorrowFee,
        uint256 minHealthFactor
    ) internal {
        Position storage position = positions[positionOwner];

        position.lastUpdateTime = uint32(block.timestamp);
        position.body = newBody;
        position.interest = newInterest;
        position.borrowFee = newBorrowFee;
        position.collaterals = collaterals;

        uint healthFactor = _calculateHealthFactor(position);

        if (healthFactor < minHealthFactor)
            revert HealthFactorTooLow(healthFactor);

        emit PositionUpdated(
            positionOwner,
            collaterals,
            newBody,
            newInterest,
            newBorrowFee,
            healthFactor
        );
    }

    function _closePosition(
        address positionOwner,
        CollateralData[] storage collaterals,
        bool toUnwrap
    ) internal {
        for (uint i = 0; i < collaterals.length; i++) {
            _withdrawAssets(
                collaterals[i].token,
                positionOwner,
                collaterals[i].amount,
                toUnwrap
            );
        }
        delete positions[positionOwner];

        emit PositionClosed(positionOwner);
    }

    ///@dev this function is used when user sent not enough XUSD to close position completely
    function _partialClose(
        address positionOwner,
        uint amountXUSD,
        uint body,
        uint112 interest,
        uint112 borrowFee
    ) internal {
        uint112 debtWithoutBody = interest + borrowFee;

        if (amountXUSD > debtWithoutBody) {
            uint leftover = amountXUSD - debtWithoutBody;

            accumulatedFees += debtWithoutBody;

            interest = 0;
            borrowFee = 0;

            if (leftover > 0) {
                body -= leftover;
                XUSD.burn(address(this), leftover);
            }
        } else {
            if (amountXUSD > borrowFee) {
                uint leftover = uint(amountXUSD) - uint(borrowFee);

                accumulatedFees += borrowFee;
                accumulatedFees += leftover;

                borrowFee = 0;
                interest -= uint112(leftover);
            } else {
                borrowFee -= uint112(amountXUSD);
                accumulatedFees += amountXUSD;
            }
        }

        _updatePosition(
            positionOwner,
            positions[positionOwner].collaterals,
            body,
            interest,
            borrowFee,
            (ray * collateralRatio) / liquidationRatio
        );
    }
}
