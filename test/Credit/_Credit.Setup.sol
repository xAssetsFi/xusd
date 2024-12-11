// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Oracle} from "../mock/Oracle.sol";
import {WETH} from "../mock/WETH.sol";

import {Credit} from "src/Credit.sol";
import {XUSD} from "src/XUSD.sol";

import {ERC20Mock} from "../mock/ERC20.sol";

import {Deploy} from "script/Deploy.sol";

contract CreditTestSetup is Test, Deploy {
    Oracle OracleUSDT;
    Oracle OracleETH;
    ERC20Mock USDT;
    XUSD xusd;
    WETH weth;
    Credit credit;

    uint256 maxAmountToMintXUSD = 500_000 * 10 ** 18;
    address public deployer;
    address public liquidator;

    function setUp() public {
        uint256 pk;

        (deployer, pk) = _createUser("Deployer");
        (liquidator, ) = _createUser("Liquidator");

        vm.startPrank(deployer);

        OracleUSDT = new Oracle();
        OracleETH = new Oracle();
        USDT = new ERC20Mock();
        weth = new WETH();

        (xusd, credit) = _deploy(pk, address(weth));

        OracleETH.setAnswer(2500 * 1e8);
        OracleUSDT.setAnswer(1 * 1e8);

        credit.addNewAllowedCollateral(address(USDT), address(OracleUSDT));
        credit.addNewAllowedCollateral(address(weth), address(OracleETH));

        vm.stopPrank();

        _afterSetUp();
    }

    function _afterSetUp() internal {
        USDT.mint(address(this), 1e8 ether);
        USDT.approve(address(credit), 1e8 ether);

        weth.approve(address(credit), 1e18 ether);
    }

    function _createUser(
        string memory name
    ) internal returns (address user, uint256 pk) {
        pk = uint256(keccak256(abi.encodePacked(name)));
        user = vm.createWallet(pk).addr;
        vm.label(user, name);
        vm.deal(user, 1e8 ether);
    }

    receive() external payable {}
}
