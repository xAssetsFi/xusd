// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {State} from "./State.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Admin is Ownable, Pausable, State {
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawAccumulatedFees(
        address receiver
    ) external nonReentrant onlyOwner {
        XUSD.transfer(receiver, accumulatedFees);
        accumulatedFees = 0;
    }

    function withdrawAccumulatedPenalties(
        address token,
        address receiver
    ) external nonReentrant onlyOwner {
        IERC20(token).transfer(receiver, accumulatedPenalties[token]);
        accumulatedPenalties[token] = 0;
    }

    ///@dev set new value to max amount to mint variable in XUSD contract, but it not update the time
    function setMaxAmountToMint(uint value) external onlyOwner {
        XUSD.setMaxAmountToMint(value);
    }

    ///@dev bad function for migration, should be different, more trustless way
    function transferOwnershipXUSD(address newOwner) external onlyOwner {
        Ownable(address(XUSD)).transferOwnership(newOwner);
    }

    function addNewAllowedCollateral(
        address token,
        address priceOracle
    ) external onlyOwner {
        priceFeeds[token] = priceOracle;
        emit NewAllowedCollateral(token, priceOracle);
    }

    function changeOracle(address token, address oracle) external onlyOwner {
        priceFeeds[token] = oracle;
    }
}
