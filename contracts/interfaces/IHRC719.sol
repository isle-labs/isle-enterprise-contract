// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/// @title IHRC719
/// @notice The token-association facade every Hedera Token Service (HTS) token exposes at its own address.
/// @dev See https://hips.hedera.com/hip/hip-719. Declared locally rather than pulled from the
///      `hedera-forking` package so the protocol contracts carry no dependency on that dev tooling.
interface IHRC719 {
    /// @notice Associates the calling account with this token.
    /// @return responseCode_ The Hedera response code for the operation.
    function associate() external returns (uint256 responseCode_);

    /// @notice Dissociates the calling account from this token.
    /// @return responseCode_ The Hedera response code for the operation.
    function dissociate() external returns (uint256 responseCode_);

    /// @notice Whether the calling account is already associated with this token.
    function isAssociated() external view returns (bool associated_);
}
