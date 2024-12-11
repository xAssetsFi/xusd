// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Credit} from "../src/Credit.sol";
import {XUSD} from "../src/XUSD.sol";

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {Deploy} from "./Deploy.sol";
import {Oracle} from "../test/mock/Oracle.sol";

import {FileUtils} from "../utils/FileHelpers.sol";

contract DeployScript is Script, Deploy {
    FileUtils fileUtils = new FileUtils();

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wxfiAddress = 0x28cC5eDd54B1E4565317C3e0Cfab551926A4CD2a;
        address wbtcAddress = 0x914938e817bd0b5f7984007dA6D27ca2EfB9f8f4;
        address wethAddress = 0x74f4B6c7F7F518202231b58CE6e8736DF6B50A81;
        address usdtAddress = 0x83E9A41c38D71f7a06632dE275877FcA48827870;

        int256 wxfiPrice = 75 * 1e6;
        int256 wbtcPrice = 63612 * 1e8;
        int256 wethPrice = 2639 * 1e8;
        int256 usdtPrice = 1 * 1e8;

        vm.startBroadcast(deployerPrivateKey);
        (XUSD xusd, Credit credit) = _deploy(deployerPrivateKey, wxfiAddress);

        Oracle oracleWXFI = _deployOracle();
        Oracle oracleWBTC = _deployOracle();
        Oracle oracleWETH = _deployOracle();
        Oracle oracleUSDT = _deployOracle();

        oracleWXFI.setAnswer(wxfiPrice);
        oracleWBTC.setAnswer(wbtcPrice);
        oracleWETH.setAnswer(wethPrice);
        oracleUSDT.setAnswer(usdtPrice);

        credit.addNewAllowedCollateral(wxfiAddress, address(oracleWXFI));
        credit.addNewAllowedCollateral(wbtcAddress, address(oracleWBTC));
        credit.addNewAllowedCollateral(wethAddress, address(oracleWETH));
        credit.addNewAllowedCollateral(usdtAddress, address(oracleUSDT));

        vm.stopBroadcast();

        console2.log("oracleWXFI", address(oracleWXFI));
        console2.log("oracleWBTC", address(oracleWBTC));
        console2.log("oracleWETH", address(oracleWETH));
        console2.log("oracleUSDT", address(oracleUSDT));
        console2.log("xusd", address(xusd));
        console2.log("credit", address(credit));

        uint32 chainId = uint32(block.chainid);

        fileUtils.writeContractAddress(
            chainId,
            address(oracleWXFI),
            "oracleWXFI"
        );
        fileUtils.writeContractAddress(
            chainId,
            address(oracleWBTC),
            "oracleWBTC"
        );
        fileUtils.writeContractAddress(
            chainId,
            address(oracleWETH),
            "oracleWETH"
        );
        fileUtils.writeContractAddress(
            chainId,
            address(oracleUSDT),
            "oracleUSDT"
        );
        fileUtils.writeContractAddress(chainId, address(xusd), "xusd");
        fileUtils.writeContractAddress(chainId, address(credit), "credit");
    }
}
