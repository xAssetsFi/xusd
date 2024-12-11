// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Positions} from "./CreditModules/Positions.sol";
import {Admin, Ownable} from "./CreditModules/Admin.sol";

import {IXUSD} from "./interfaces/IXUSD.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IChainlinkPriceOracle} from "./interfaces/IChainlinkPriceOracle.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console2} from "forge-std/console2.sol";

contract Credit is Admin, Positions {
    using SafeERC20 for IERC20;

    constructor(
        address _xusdAddress,
        address _wethAddress
    ) Ownable(msg.sender) {
        if (_xusdAddress == address(0)) revert ZeroAddress("XUSD");
        if (_wethAddress == address(0)) revert ZeroAddress("WETH");

        XUSD = IXUSD(_xusdAddress);
        WETH = IWETH(_wethAddress);
    }

    function takeLoanETH(uint256 amountOut) external payable {
        WETH.deposit{value: msg.value}();
        _takeLoan(address(WETH), msg.value, amountOut);
    }

    function takeLoan(
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) external payable {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        _takeLoan(token, amountIn, amountOut);
    }

    function _takeLoan(
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) internal whenNotPaused nonReentrant isCollateral(token) {
        require(
            amountOut >= 1e18,
            "Credit: Body of credit must be greater than 1 XUSD"
        );

        require(
            !positions[msg.sender].isInitialized,
            "Credit: User already has credit position"
        );

        _createNewPosition(msg.sender, token, amountIn, amountOut);
    }

    function repayLoanAndUnwrap(uint256 amountXUSD) external {
        _repayLoan(amountXUSD, true);
    }

    function repayLoan(uint256 amountXUSD) external {
        _repayLoan(amountXUSD, false);
    }

    function _repayLoan(
        uint256 amountXUSD,
        bool toUnwrap
    ) internal nonReentrant initializedPosition(msg.sender) {
        Position storage position = positions[msg.sender];

        uint body = position.body;
        uint112 interest = _calculateTotalInterest(position);
        uint112 borrowFee = position.borrowFee;

        uint debt = body + interest + borrowFee;

        if (amountXUSD >= debt) {
            XUSD.transferFrom(msg.sender, address(this), debt);
            XUSD.burn(address(this), body);
            accumulatedFees += interest + borrowFee;

            _closePosition(msg.sender, position.collaterals, toUnwrap);
        } else {
            XUSD.transferFrom(msg.sender, address(this), amountXUSD);
            _partialClose(msg.sender, amountXUSD, body, interest, borrowFee);
        }
    }

    function addCollateralETH() public payable {
        WETH.deposit{value: msg.value}();
        _addCollateral(address(WETH), msg.value);
    }

    function addCollateral(address token, uint256 amountIn) public {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        _addCollateral(token, amountIn);
    }

    function _addCollateral(
        address token,
        uint256 amountIn
    )
        internal
        nonReentrant
        initializedPosition(msg.sender)
        isCollateral(token)
    {
        require(amountIn > 0, "Credit: Sent incorrect collateral amount");

        Position storage position = positions[msg.sender];

        bool isTokenExists = false;

        for (uint i = 0; i < position.collaterals.length; i++) {
            if (position.collaterals[i].token == token) {
                position.collaterals[i].amount += amountIn;
                isTokenExists = true;
                break;
            }
        }

        if (!isTokenExists) {
            position.collaterals.push(CollateralData(token, amountIn));
        }

        _updatePosition(
            msg.sender,
            position.collaterals,
            position.body,
            _calculateTotalInterest(position),
            position.borrowFee,
            ray
        );
    }

    function takeAdditionalLoan(
        uint amountToMint
    ) public whenNotPaused nonReentrant initializedPosition(msg.sender) {
        require(amountToMint > 0, "Credit: incorrect amount to mint");

        Position storage position = positions[msg.sender];

        uint newBody = position.body + amountToMint;

        uint112 newBorrowFee = uint112(
            position.borrowFee +
                (amountToMint * borrowFeePercentagePoint) /
                precisionMultiplier
        );

        XUSD.mint(msg.sender, amountToMint);

        _updatePosition(
            msg.sender,
            position.collaterals,
            newBody,
            _calculateTotalInterest(position),
            newBorrowFee,
            (ray * collateralRatio) / liquidationRatio
        );
    }

    function withdrawCollateralETH(uint256 amountIn) external {
        _withdrawCollateral(address(WETH), amountIn);
        _withdrawAssets(address(WETH), msg.sender, amountIn, true);
    }

    function withdrawCollateral(address token, uint256 amountIn) external {
        _withdrawCollateral(token, amountIn);
        _withdrawAssets(token, msg.sender, amountIn, false);
    }

    function _withdrawCollateral(
        address token,
        uint withdrawAmount
    ) internal nonReentrant initializedPosition(msg.sender) {
        Position storage position = positions[msg.sender];

        _decreaseCollateral(position, token, withdrawAmount);

        _updatePosition(
            msg.sender,
            position.collaterals,
            position.body,
            _calculateTotalInterest(position),
            position.borrowFee,
            (ray * collateralRatio) / liquidationRatio
        );
    }

    function liquidateETH(address positionOwner, uint256 amountXUSD) external {
        _liquidate(positionOwner, address(WETH), amountXUSD, true);
    }

    function liquidate(
        address positionOwner,
        address token,
        uint256 amountXUSD
    ) external {
        _liquidate(positionOwner, token, amountXUSD, false);
    }

    function _liquidate(
        address positionOwner,
        address token,
        uint256 amountXUSD,
        bool toUnwrap
    )
        internal
        nonReentrant
        initializedPosition(positionOwner)
        isCollateral(token)
    {
        Position storage position = positions[positionOwner];

        uint healthFactor = _calculateHealthFactor(position);
        require(healthFactor < ray, "Credit: position is healthy");

        require(
            amountXUSD * 2 <= getTotalDebt(positionOwner),
            "Credit: Liquidation amount is too high"
        );

        uint256 collateralPrice = uint(getPriceFeeds(token));
        uint256 baseAmountToLiquidator = (amountXUSD * oraclePrecision) /
            collateralPrice; // amount in collateral token, equivalent to amountXUSDToRepay
        uint256 liquidationBonus = (baseAmountToLiquidator *
            liquidationBonusPercentagePoint) / precisionMultiplier; // bonus for liquidator in collateral token
        uint256 ttlToLiq = baseAmountToLiquidator + liquidationBonus;
        uint256 penalty = (baseAmountToLiquidator *
            liquidationPenaltyPercentagePoint) / precisionMultiplier; // penalty to platform due liquidation in collateral token

        XUSD.burn(msg.sender, amountXUSD);
        accumulatedPenalties[token] += penalty;
        _decreaseCollateral(position, token, ttlToLiq + penalty);
        _withdrawAssets(token, msg.sender, ttlToLiq, toUnwrap);

        _updatePosition(
            positionOwner,
            position.collaterals,
            position.body - amountXUSD,
            _calculateTotalInterest(position),
            position.borrowFee,
            0
        );

        emit Liquidation(
            positionOwner,
            token,
            msg.sender,
            amountXUSD,
            ttlToLiq,
            penalty,
            healthFactor
        );
    }

    function addCollateralAndTakeAdditionalLoan(
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) external {
        addCollateral(token, amountIn);
        takeAdditionalLoan(amountOut);
    }

    function addCollateralETHAndTakeAdditionalLoan(
        uint256 amountOut
    ) external payable {
        addCollateralETH();
        takeAdditionalLoan(amountOut);
    }

    function mintXUSD(
        uint256 amount,
        address to
    ) external onlyOwner onlyOwner onlyOwner {
        XUSD.mint(to, amount);
    }
}
