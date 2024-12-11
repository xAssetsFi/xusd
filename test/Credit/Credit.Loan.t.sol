// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {CreditTestSetup} from "./_Credit.Setup.sol";

import {ICredit} from "src/interfaces/ICredit.sol";

contract CreditLoanTest is CreditTestSetup {
    modifier checkersForTakeLoan(uint256 loanXUSDAmount) {
        vm.assume(
            loanXUSDAmount > 1e18 &&
                loanXUSDAmount <= USDT.balanceOf(address(this)) &&
                loanXUSDAmount < maxAmountToMintXUSD
        );

        _;

        ICredit.Position memory position = credit.getPosition(address(this));

        assertEq(position.body, loanXUSDAmount);
    }

    function testFuzz_takeLoan(
        uint256 loanXUSDAmount
    ) public checkersForTakeLoan(loanXUSDAmount) {
        uint256 collateralAmount = loanXUSDAmount * credit.collateralRatio();

        uint256 balanceBefore = USDT.balanceOf(address(this));

        USDT.approve(address(credit), collateralAmount);
        credit.takeLoan(address(USDT), collateralAmount, loanXUSDAmount);

        assertEq(
            USDT.balanceOf(address(this)),
            balanceBefore - collateralAmount
        );
    }

    function testFuzz_takeLoanETH(
        uint256 loanXUSDAmount
    ) public checkersForTakeLoan(loanXUSDAmount) {
        uint256 collateralAmount = loanXUSDAmount * credit.collateralRatio();

        uint256 balanceBefore = address(this).balance;

        credit.takeLoanETH{value: collateralAmount}(loanXUSDAmount);

        assertEq(address(this).balance, balanceBefore - collateralAmount);
    }

    function testFuzz_takeAdditionalLoan(uint256 loanXUSDAmount) public {
        uint256 additionalLoanXUSDAmount = loanXUSDAmount / 4;
        vm.assume(
            loanXUSDAmount > 1e18 &&
                loanXUSDAmount <= USDT.balanceOf(address(this)) &&
                loanXUSDAmount + additionalLoanXUSDAmount < maxAmountToMintXUSD
        );
        uint256 collateralAmount = loanXUSDAmount *
            credit.collateralRatio() *
            5;

        USDT.approve(address(credit), collateralAmount);
        credit.takeLoan(address(USDT), collateralAmount, loanXUSDAmount);

        uint256 healthFactorBefore = credit.getHealthFactor(address(this));
        uint256 balanceBefore = xusd.balanceOf(address(this));

        credit.takeAdditionalLoan(additionalLoanXUSDAmount);

        assertEq(
            xusd.balanceOf(address(this)),
            balanceBefore + additionalLoanXUSDAmount
        );

        uint256 healthFactorAfter = credit.getHealthFactor(address(this));
        assertLt(healthFactorAfter, healthFactorBefore);
    }

    function testFuzz_repayLoan(uint256 loanXUSDAmount) public {
        vm.assume(
            loanXUSDAmount > 10 ** xusd.decimals() &&
                loanXUSDAmount <= USDT.balanceOf(address(this)) &&
                loanXUSDAmount < maxAmountToMintXUSD
        );
        assertEq(USDT.balanceOf(address(credit)), 0);

        uint256 userBalanceBefore = USDT.balanceOf(address(this));

        uint256 collateralAmount = loanXUSDAmount * credit.collateralRatio();
        USDT.approve(address(credit), collateralAmount);
        xusd.approve(address(credit), type(uint256).max);

        credit.takeLoan(address(USDT), collateralAmount, loanXUSDAmount);

        uint256 healthFactor = credit.getHealthFactor(address(this));
        ICredit.Position memory position = credit.getPosition(address(this));
        assertEq(position.body, loanXUSDAmount);

        credit.repayLoan(loanXUSDAmount / 2);

        position = credit.getPosition(address(this));
        assertLt(position.body, loanXUSDAmount);
        assertGt(credit.getHealthFactor(address(this)), healthFactor);

        deal(address(xusd), address(this), credit.getTotalDebt(address(this)));
        credit.repayLoan(type(uint256).max);

        vm.expectRevert(ICredit.PositionNotExists.selector);
        position = credit.getPosition(address(this));

        assertEq(USDT.balanceOf(address(credit)), 0);
        assertEq(USDT.balanceOf(address(this)), userBalanceBefore);
    }

    function testFuzz_repayLoanAndUnwrap(uint256 loanXUSDAmount) public {
        uint256 balanceBefore = address(this).balance;

        vm.assume(
            loanXUSDAmount > 1e18 &&
                loanXUSDAmount <= balanceBefore &&
                loanXUSDAmount < maxAmountToMintXUSD
        );

        uint256 collateralAmount = loanXUSDAmount * credit.collateralRatio();

        credit.takeLoanETH{value: collateralAmount}(loanXUSDAmount);

        xusd.approve(address(credit), type(uint256).max);
        deal(address(xusd), address(this), credit.getTotalDebt(address(this)));
        credit.repayLoanAndUnwrap(type(uint256).max);

        vm.expectRevert(ICredit.PositionNotExists.selector);
        credit.getPosition(address(this));

        assertEq(address(this).balance, balanceBefore);
    }
}
