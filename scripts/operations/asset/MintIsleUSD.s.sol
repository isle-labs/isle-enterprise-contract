// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20Mint } from "scripts/deployments/contracts/ERC20Mint.sol";

import { BuyerActor } from "scripts/actors/Buyer.s.sol";

/// @notice Mints testnet IsleUSD to an arbitrary beneficiary. Self-serve; uses the
///         buyer key by convention but any signer can call ERC20Mint.mint.
contract MintIsleUSD is BuyerActor {
    function run() public {
        address asset = readSingleton("IsleUSD");
        address beneficiary = promptAddress("Beneficiary address");
        uint256 amount = promptUint("Mint amount (raw uint)");
        _mint(asset, beneficiary, amount);
    }

    function _mint(address asset, address to, uint256 amount) internal asBuyer {
        IERC20Mint(asset).mint(to, amount);
    }
}
