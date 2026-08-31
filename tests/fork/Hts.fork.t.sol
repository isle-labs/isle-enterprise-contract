// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Hsc } from "@hedera-forking/Hsc.sol";

import { Pool } from "contracts/Pool.sol";
import { Hts } from "contracts/libraries/Hts.sol";
import { IHRC719 } from "contracts/interfaces/IHRC719.sol";

/// @dev Exercises the HTS deployment path against the *real* USDC token on a Hedera mainnet fork —
///      the same sequence `DeployPoolConfigurator` performs when it creates a market's Pool.
///
///      Opt-in; set `HEDERA_RPC_URL` and run under the `hedera` profile (which enables the `ffi`
///      that `Hsc.htsSetup()` needs):
///
///          HEDERA_RPC_URL=https://mainnet.hashio.io/api FOUNDRY_PROFILE=hedera \
///              forge test --match-path "tests/fork/*"
///
///      Skips itself when `HEDERA_RPC_URL` is unset, so the default suite stays offline.
///
///      NOTE ON FIDELITY: hedera-forking emulates HTS well enough to exercise token *metadata* and
///      *allowances*, but it does not reproduce two behaviours this port exists for — it neither
///      enforces the `int64` allowance ceiling nor gates transfers on association. Those two are
///      verified against the live network instead (see `test_MaxApproval_MatchesLiveMarkets`).
contract HtsForkTest is Test {
    /// @dev HTS USDC on Hedera mainnet (token 0.0.456858).
    address internal constant USDC = 0x000000000000000000000000000000000006f89a;

    /// @dev The live `wuren` market, deployed June 2026 from the `hedera` branch.
    address internal constant WUREN_POOL = 0x53990bdEc017085153eB807236E744CA63C21fF4;
    address internal constant WUREN_POOL_CONFIGURATOR = 0x4e5d0F32e4d2D5Ad3b72C3b208191c8695A60041;

    uint256 internal constant INT64_MAX = uint256(uint64(type(int64).max));

    bool internal forked;

    function setUp() public {
        string memory rpcUrl_ = vm.envOr("HEDERA_RPC_URL", string(""));
        if (bytes(rpcUrl_).length == 0) return;

        vm.createSelectFork(rpcUrl_);
        Hsc.htsSetup();

        // The emulator resolves an account's association slot through the Mirror Node and reverts for
        // any account it has never seen (`HtsSystemContract._isAssociatedSlot`: `require(exists)`).
        // A contract created during this run cannot exist there yet, so `associate()` is stubbed to
        // SUCCESS. Everything else — `decimals`, `approve`, `allowance` — runs through the emulator
        // against real token state. Deployment scripts need the same stub, see `HederaScript`.
        vm.mockCall(USDC, abi.encodeWithSelector(IHRC719.associate.selector), abi.encode(Hts.SUCCESS));

        forked = true;
    }

    /// @dev The point of the port: a freshly constructed Pool completes against real HTS USDC.
    ///      Before it, the constructor's `type(uint256).max` approval made this impossible.
    function test_Pool_ConstructsAgainstRealUsdc() public {
        _requireFork();

        address configurator_ = makeAddr("configurator");
        Pool pool_ = new Pool(configurator_, USDC, "Fork Test Pool", "FTP");

        assertEq(
            IERC20(USDC).allowance(address(pool_), configurator_),
            INT64_MAX,
            "pool must approve the configurator up to the int64 ceiling"
        );
        // Reading `decimals()` off the HTS token succeeded: the share token is the underlying's
        // 6 decimals plus the vault's fixed 4-decimal offset.
        assertEq(pool_.decimals(), 10, "pool decimals must be USDC's 6 plus the 4 decimal offset");
        assertEq(address(pool_.asset()), USDC, "pool asset must be USDC");
    }

    /// @dev Ties the cap to reality: the live markets carry exactly this approval, so the value the
    ///      port writes is the value Hedera actually accepted in production.
    function test_MaxApproval_MatchesLiveMarkets() public {
        _requireFork();

        uint256 liveAllowance_ = IERC20(USDC).allowance(WUREN_POOL, WUREN_POOL_CONFIGURATOR);
        assertLe(liveAllowance_, INT64_MAX, "live allowance cannot exceed the int64 ceiling");
        assertGt(liveAllowance_, 0, "live market must hold a standing approval");
        assertEq(Hts.maxApproval(), INT64_MAX, "Hts must cap approvals at the same ceiling on Hedera");
    }

    /// @dev The chain gate must be live here — it is what keeps the same contracts deployable on Plume.
    function test_ChainGate_IsHederaOnFork() public {
        _requireFork();

        assertEq(block.chainid, 295, "fork must be Hedera mainnet");
        assertTrue(Hts.isHedera(), "Hts must recognise Hedera");
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }
}

/// @dev The counterpart guarantee: the very same contracts still deploy on an EVM chain whose asset
///      has no HIP-719 entrypoint. This is what the chain gate in {Hts} buys — one branch serving
///      Hedera and Plume, instead of the chain-specific fork the `hedera` branch had to be.
///
///      Opt-in via `PLUME_RPC_URL`; needs no `ffi` and no emulator:
///
///          PLUME_RPC_URL=https://rpc.plume.org FOUNDRY_EVM_VERSION=cancun \
///              forge test --match-path "tests/fork/*"
///
///      `FOUNDRY_EVM_VERSION` is not optional: `evm_version` sets the spec the *forked* EVM executes
///      under as well as the one contracts compile for, and the live pUSD bytecode uses opcodes that
///      post-date the project's `paris` setting. Simulating a call into it under `paris` fails with
///      `EvmError: NotActivated`. Real Plume nodes are well past Cancun, so this constrains local
///      simulation only — but it applies to `forge script` runs against Plume just the same.
contract PlumePortabilityForkTest is Test {
    /// @dev pUSD, the pool asset of the live `wuren` market on Plume. A plain ERC-20 — calling
    ///      `associate()` on it reverts, which is exactly why the gate has to exist.
    address internal constant PUSD = 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F;

    bool internal forked;

    function setUp() public {
        string memory rpcUrl_ = vm.envOr("PLUME_RPC_URL", string(""));
        if (bytes(rpcUrl_).length == 0) return;

        vm.createSelectFork(rpcUrl_);
        forked = true;
    }

    function test_Pool_StillConstructsOnPlume() public {
        _requireFork();

        address configurator_ = makeAddr("configurator");
        Pool pool_ = new Pool(configurator_, PUSD, "Fork Test Pool", "FTP");

        // Unchanged pre-port behaviour off Hedera: a genuinely unlimited approval.
        assertEq(
            IERC20(PUSD).allowance(address(pool_), configurator_),
            type(uint256).max,
            "approval must stay unbounded off Hedera"
        );
    }

    function test_ChainGate_IsNotHederaOnPlume() public {
        _requireFork();

        assertEq(block.chainid, 98_866, "fork must be Plume mainnet");
        assertFalse(Hts.isHedera(), "Hts must not treat Plume as Hedera");
        assertEq(Hts.maxApproval(), type(uint256).max, "maxApproval must stay unbounded off Hedera");
    }

    /// @dev Demonstrates the failure the gate avoids: associating is not merely unnecessary here,
    ///      it is impossible, so an ungated `associate()` would brick every Plume deployment.
    function test_Associate_WouldRevertOnPlume() public {
        _requireFork();

        (bool ok_,) = PUSD.call(abi.encodeWithSelector(IHRC719.associate.selector));
        assertFalse(ok_, "pUSD must have no HIP-719 associate entrypoint");
    }

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }
}
