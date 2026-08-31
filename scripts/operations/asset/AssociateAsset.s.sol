// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Hts } from "contracts/libraries/Hts.sol";
import { IHRC719 } from "contracts/interfaces/IHRC719.sol";

import { HtsSimulation } from "scripts/hedera/HtsSimulation.sol";
import { BaseScript } from "scripts/Base.s.sol";

/// @notice Associates an externally-owned account with an HTS asset so it can hold that token.
///
/// @dev Only the account itself can associate itself, so this broadcasts as the account you supply —
///      the CLI signer must match it. Run once per EOA that will touch the asset on a new Hedera
///      market. The protocol contracts do this themselves during deployment and need no run here.
///
///      Who needs it, from the flow of funds in `LoanManager._distribute` / `Pool` / `PoolConfigurator`:
///        - pool admin  — receives `adminFee`, and posts first-loss cover
///        - isleVault   — receives `protocolFee`
///        - seller      — receives loan proceeds via `withdrawFunds`
///        - buyer       — pays principal + interest at `repayLoan`
///        - lender(s)   — deposit into and redeem from the Pool
///
///      Accounts reused from an existing market (`wuren`, `chipright`) are already associated;
///      associating again is harmless — HTS answers `TOKEN_ALREADY_ASSOCIATED_TO_ACCOUNT`, which
///      {Hts} treats as success.
///
///      usage: FOUNDRY_PROFILE=hedera forge script AssociateAsset --rpc-url <url> --ledger --broadcast
contract AssociateAsset is BaseScript {
    function run() public {
        address asset = promptAddress("Asset address (hedera USDC: 0x000000000000000000000000000000000006f89a)");
        address account = promptAddress("Account to associate (must match the CLI signer)");

        require(Hts.isHedera(), "AssociateAsset: only meaningful on Hedera");

        // The account already exists on-chain, so the emulator can resolve it; no associate stub needed.
        HtsSimulation.emulate();

        vm.startBroadcast(account);
        IHRC719(asset).associate();
        vm.stopBroadcast();
    }
}
