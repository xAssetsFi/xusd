// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Credit} from "../src/Credit.sol";
import {XUSD} from "../src/XUSD.sol";

import {CommonBase} from "lib/forge-std/src/Base.sol";
import {Oracle} from "../test/mock/Oracle.sol";

import {console2} from "forge-std/Script.sol";

contract Deploy is CommonBase {
    function _deploy(
        uint256 deployerPrivateKey,
        address wethAddress
    ) internal returns (XUSD xusd, Credit credit) {
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        uint256 nonce = vm.getNonce(deployer);
        console2.log("nonce", nonce);
        address computedCreditAddress = vm.computeCreateAddress(
            deployer,
            nonce + 1
        );
        console2.log("computedCreditAddress", computedCreditAddress);

        xusd = _deployXUSD(computedCreditAddress);
        credit = _deployCredit(xusd, wethAddress);

        vm.assertEq(
            computedCreditAddress,
            address(credit),
            "Credit address is not computed correctly, try to increment or decrement nonce"
        );
    }

    function _deployXUSD(address credit) private returns (XUSD) {
        return new XUSD(credit);
    }

    function _deployCredit(
        XUSD xusd,
        address wethAddress
    ) private returns (Credit) {
        return new Credit(address(xusd), wethAddress);
    }

    function _deployOracle() internal returns (Oracle) {
        return new Oracle();
    }
}
