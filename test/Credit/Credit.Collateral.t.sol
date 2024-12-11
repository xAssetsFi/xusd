// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {CreditTestSetup} from "./_Credit.Setup.sol";
import {ICredit} from "src/interfaces/ICredit.sol";

contract CreditCollateralTest is CreditTestSetup {
    uint256 loanXUSDAmount;
    uint256 collateralAmountAfterTakeLoan;

    modifier checkers(bool isHFShouldIncrease) {
        loanXUSDAmount = 1 ether;
        collateralAmountAfterTakeLoan =
            loanXUSDAmount *
            credit.collateralRatio() *
            5;
        credit.takeLoan(
            address(USDT),
            collateralAmountAfterTakeLoan,
            loanXUSDAmount
        );

        uint256 healthFactorBefore = credit.getHealthFactor(address(this));
        _;
        uint256 healthFactorAfter = credit.getHealthFactor(address(this));

        if (isHFShouldIncrease) assertGt(healthFactorAfter, healthFactorBefore);
        else assertLt(healthFactorAfter, healthFactorBefore);
    }

    function testFuzz_addCollateral(uint256 amount) public checkers(true) {
        USDT.approve(address(credit), amount);
        vm.assume(amount > 0 && amount < USDT.balanceOf(address(this)));
        credit.addCollateral(address(USDT), amount);

        ICredit.Position memory position = credit.getPosition(address(this));

        assertEq(position.collaterals.length, 1);

        ICredit.CollateralData memory collateral = position.collaterals[0];

        assertEq(collateral.token, address(USDT));
        assertEq(collateral.amount, amount + collateralAmountAfterTakeLoan);
    }

    function testFuzz_addCollateralETH(uint256 amount) public checkers(true) {
        vm.assume(amount > 0 && amount < address(this).balance);
        credit.addCollateralETH{value: amount}();

        ICredit.Position memory position = credit.getPosition(address(this));

        assertEq(position.collaterals.length, 2);

        ICredit.CollateralData memory collateral = position.collaterals[1];

        assertEq(collateral.token, address(weth));
        assertEq(collateral.amount, amount);
    }

    function testFuzz_withdrawCollateral(
        uint256 amount
    ) public checkers(false) {
        vm.assume(
            amount > 0 &&
                collateralAmountAfterTakeLoan > amount &&
                collateralAmountAfterTakeLoan - amount >
                loanXUSDAmount * credit.liquidationRatio()
        );

        uint256 balanceBefore = USDT.balanceOf(address(this));
        credit.withdrawCollateral(address(USDT), amount);
        uint256 balanceAfter = USDT.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function testFuzz_withdrawCollateralETH(
        uint256 amount
    ) public checkers(true) {
        vm.assume(amount > 1 && amount < collateralAmountAfterTakeLoan);
        credit.addCollateralETH{value: amount}();
        uint256 healthFactorBefore = credit.getHealthFactor(address(this));
        credit.withdrawCollateralETH(amount / 2);
        uint256 healthFactorAfter = credit.getHealthFactor(address(this));

        assertLt(healthFactorAfter, healthFactorBefore);
    }
}
