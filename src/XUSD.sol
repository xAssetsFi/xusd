// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IXUSD} from "./interfaces/IXUSD.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TODO: Create additional contract CreditContractManager that allows to add/remove new credit contracts
// note after launch new Credit contract that supports ERC20 collateral credits can be added as minter
contract XUSD is IXUSD, Ownable, ERC20 {
    uint private _timeTrigger;
    uint private _maxAmountToMint = 500_000 * 10 ** 18; // 500_000$
    uint private constant _mintingUpdate = 1 days;
    uint private _totalMintedAmountPerTime; //total mint per 1 minting Update

    constructor(
        address CreditContract
    ) ERC20("CrossFiUSD", "XUSD") Ownable(CreditContract) {}

    modifier isAvailableToMint(uint amountToMint) {
        uint currentTime = block.timestamp;
        // require(currentTime - _timeTrigger);
        if (currentTime - _timeTrigger < _mintingUpdate) {
            require(
                amountToMint <= _maxAmountToMint - _totalMintedAmountPerTime,
                "XUSD: Minting Limit is exceeded"
            );
        } else {
            _timeTrigger = currentTime;
            _totalMintedAmountPerTime = 0;
            require(
                amountToMint <= _maxAmountToMint,
                "XUSD: Minting Limit is exceeded"
            );
        }
        _;
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner isAvailableToMint(amount) {
        _totalMintedAmountPerTime += amount;
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function setMaxAmountToMint(uint value) external onlyOwner {
        _maxAmountToMint = value;
    }

    function getMaxAmountToMint() external view returns (uint) {
        return _maxAmountToMint;
    }
}
