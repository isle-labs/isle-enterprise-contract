// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { DeployerActor } from "scripts/actors/Deployer.s.sol";
import { ERC20Mint } from "scripts/deployments/contracts/ERC20Mint.sol";

/// @notice Deploys the mintable testnet IsleUSD asset.
/// @notice usage: forge script DeployIsleUSD --rpc-url <url> --broadcast
contract DeployIsleUSD is DeployerActor {
    function run() public {
        uint8 decimals = uint8(promptUint("IsleUSD decimals (default 6 for USDC parity)"));
        ERC20 asset = _deploy(decimals);
        writeSingleton("IsleUSD", address(asset));
    }

    function _deploy(uint8 decimals_) internal asDeployer returns (ERC20) {
        return new ERC20Mint("Isle USD", "IUSD", decimals_);
    }
}
