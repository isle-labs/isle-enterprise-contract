// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "./Errors.sol";

import { IHRC719 } from "../interfaces/IHRC719.sol";

/// @title Hts
/// @notice Chain-gated helpers for holding a Hedera Token Service (HTS) token, such as USDC on Hedera.
/// @dev Two HTS rules break code that is otherwise perfectly valid ERC-20 code:
///
///      1. An account cannot hold, receive or approve an HTS token until it has *associated* itself with
///         that token. Contracts deployed through the EVM are created with zero auto-association slots
///         (verified on the live markets: `max_automatic_token_associations == 0`), so association is
///         never implicit — the contract must call {IHRC719-associate} on itself.
///      2. HTS stores balances and allowances as `int64`, so the customary `type(uint256).max` approval
///         reverts. Approvals must be capped at `int64` max.
///
///      Both helpers are no-ops off Hedera, where the pool asset is a plain ERC-20 with no HIP-719
///      entrypoint — calling `associate()` on such a token reverts. This keeps one set of contracts
///      deployable on Hedera and on the EVM chains (Plume) from the same branch.
library Hts {
    /// @dev https://hips.hedera.com/hip/hip-30
    uint256 internal constant MAINNET_CHAIN_ID = 295;
    uint256 internal constant TESTNET_CHAIN_ID = 296;
    uint256 internal constant PREVIEWNET_CHAIN_ID = 297;

    /// @dev Hedera response code for a successful operation.
    uint256 internal constant SUCCESS = 22;

    /// @dev Hedera response code returned when the account is already associated. Benign: association is
    ///      idempotent from the protocol's point of view, so this is accepted alongside {SUCCESS}.
    uint256 internal constant TOKEN_ALREADY_ASSOCIATED_TO_ACCOUNT = 194;

    /// @notice Whether the current chain runs Hedera Token Service.
    function isHedera() internal view returns (bool) {
        uint256 chainId_ = block.chainid;
        return chainId_ == MAINNET_CHAIN_ID || chainId_ == TESTNET_CHAIN_ID || chainId_ == PREVIEWNET_CHAIN_ID;
    }

    /// @notice Associates the calling contract with `token_` so it can hold and approve that token.
    /// @dev No-op off Hedera. Reverts on any response code other than success/already-associated, so a
    ///      failed association surfaces at deploy time instead of leaving a market that cannot be funded.
    function associate(address token_) internal {
        if (!isHedera()) return;

        uint256 responseCode_ = IHRC719(token_).associate();
        if (responseCode_ != SUCCESS && responseCode_ != TOKEN_ALREADY_ASSOCIATED_TO_ACCOUNT) {
            revert Errors.Hts_AssociateFailed({ token_: token_, responseCode_: responseCode_ });
        }
    }

    /// @notice The largest approval the pool asset can represent on the current chain.
    /// @dev `int64` max is ~9.22e18 raw units — for a 6-decimal asset that is ~9.2 trillion tokens, so it
    ///      is effectively unlimited while still fitting HTS's signed 64-bit allowance.
    function maxApproval() internal view returns (uint256) {
        return isHedera() ? uint256(uint64(type(int64).max)) : type(uint256).max;
    }
}
