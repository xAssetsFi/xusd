// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICredit {
    struct CollateralData {
        address token;
        uint256 amount;
    }

    struct Position {
        bool isInitialized;
        uint32 lastUpdateTime; // time when position was updated last time
        CollateralData[] collaterals; // collaterals that user locked in contract
        uint112 interest; // loan interest accrued from the moment the loan was taken until the lastUpdateTime
        uint112 borrowFee; // the amount of XUSD that is added to the total debt immediately upon taking out a loan
        uint256 body; // amount of XUSD
    }

    event PositionCreated(
        address indexed user,
        CollateralData[] collaterals,
        uint body,
        uint borrowFee,
        uint healthFactor
    );

    event PositionClosed(address indexed user);

    event PositionUpdated(
        address indexed user,
        CollateralData[] collaterals,
        uint newBody,
        uint newInterest,
        uint newBorrowFee,
        uint healthFactor
    );

    event Liquidation(
        address indexed positionOwner,
        address indexed token,
        address liquidator,
        uint256 xusdAmount,
        uint256 totalReturned,
        uint256 penalty,
        uint256 healthFactor
    );

    event NewAllowedCollateral(address token, address priceOracle);

    error ZeroAddress(string how);
    error PositionNotExists();
    error NotAllowedCollateral();
    error LowLevelEthTransferFailed();
    error HealthFactorTooLow(uint256 healthFactor);
    error NotEnoughCollateral(uint256 required, uint256 available);

    ///@notice you can't call this function if you already have opened position
    ///@param amountOut - amount of XUSD that user will receive
    function takeLoan(
        address token,
        uint amountIn,
        uint amountOut
    ) external payable;

    ///@notice You must have opened position before calling this function
    ///@param amountXUSD  - amount of XUSD that you want to deposit to close you position
    function repayLoan(uint256 amountXUSD) external;

    function repayLoanAndUnwrap(uint256 amountXUSD) external;

    ///@notice that you must have opened position
    function addCollateral(address token, uint amountIn) external;

    function addCollateralETH() external payable;

    ///@notice that your position will still be collateralize after taking more XUSD
    function takeAdditionalLoan(uint amountToMint) external;

    ///@notice that your position will still be collateralize after withdrawing collateral
    function withdrawCollateral(address token, uint withdrawAmount) external;

    function withdrawCollateralETH(uint256 amountIn) external;

    ///@param positionOwner - address of the position that we want to liquidate
    ///@notice that position is under collateralize before liquidation
    function liquidate(
        address positionOwner,
        address token,
        uint256 amountXUSDToRepay
    ) external;

    function liquidateETH(
        address positionOwner,
        uint256 amountXUSDToRepay
    ) external;
}
