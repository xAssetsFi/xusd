// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";

import {CreditTestSetup} from "./_Credit.Setup.sol";

import {ICredit} from "src/interfaces/ICredit.sol";

contract CreditLiquidationTest is CreditTestSetup {
    modifier liquidationSetUp(uint256 liquidateAmountXUSD) {
        vm.assume(
            liquidateAmountXUSD > 1e18 &&
                liquidateAmountXUSD < USDT.balanceOf(address(this)) &&
                liquidateAmountXUSD < maxAmountToMintXUSD
        );

        uint256 collateralAmount = liquidateAmountXUSD *
            credit.collateralRatio();

        USDT.approve(address(credit), collateralAmount);

        credit.takeLoan(address(USDT), collateralAmount, liquidateAmountXUSD);

        OracleUSDT.setAnswer((1e8 / 100) * 60);

        _;
    }

    function testFuzz_liquidate(
        uint256 liquidateAmountXUSD
    ) public liquidationSetUp(liquidateAmountXUSD) {
        assertEq(xusd.balanceOf(address(liquidator)), 0);

        uint256 totalDebt = credit.getTotalDebt(address(this));

        deal(address(xusd), address(liquidator), totalDebt);
        vm.startPrank(liquidator);
        xusd.approve(address(credit), totalDebt);

        uint256 healthFactorBefore = credit.getHealthFactor(address(this));

        credit.liquidate(
            address(this),
            address(USDT),
            credit.getTotalDebt(address(this)) / 2
        );

        uint256 healthFactorAfter = credit.getHealthFactor(address(this));
        assertGt(healthFactorAfter, healthFactorBefore);

        assertGt(USDT.balanceOf(address(liquidator)), 0);
    }
}
