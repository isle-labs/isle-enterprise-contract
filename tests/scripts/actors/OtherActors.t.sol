// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "@forge-std/Test.sol";

import { PoolAdminActor } from "scripts/actors/PoolAdmin.s.sol";
import { DeployerActor }  from "scripts/actors/Deployer.s.sol";
import { BuyerActor }     from "scripts/actors/Buyer.s.sol";
import { SellerActor }    from "scripts/actors/Seller.s.sol";
import { LenderActor }    from "scripts/actors/Lender.s.sol";

// ---------------------------------------------------------------------------
// Each harness overrides BOTH env-name getters to non-existent strings so
// _load() falls through to the mnemonic. This isolates the test from any
// env vars in the developer's shell or CI environment.
// ---------------------------------------------------------------------------

contract PoolAdminHarness is PoolAdminActor {
    function _poolAdminKeyEnvName()     internal pure override returns (string memory) { return "POOL_ADMIN_KEY_test_other"; }
    function _poolAdminAddressEnvName() internal pure override returns (string memory) { return "POOL_ADMIN_test_other"; }
    function exposed_addr() external view returns (address) { return poolAdmin; }
}

contract DeployerHarness is DeployerActor {
    function _deployerKeyEnvName()     internal pure override returns (string memory) { return "DEPLOYER_KEY_test_other"; }
    function _deployerAddressEnvName() internal pure override returns (string memory) { return "DEPLOYER_test_other"; }
    function exposed_addr() external view returns (address) { return deployer; }
}

contract BuyerHarness is BuyerActor {
    function _buyerKeyEnvName()     internal pure override returns (string memory) { return "BUYER_KEY_test_other"; }
    function _buyerAddressEnvName() internal pure override returns (string memory) { return "BUYER_test_other"; }
    function exposed_addr() external view returns (address) { return buyer; }
}

contract SellerHarness is SellerActor {
    function _sellerKeyEnvName()     internal pure override returns (string memory) { return "SELLER_KEY_test_other"; }
    function _sellerAddressEnvName() internal pure override returns (string memory) { return "SELLER_test_other"; }
    function exposed_addr() external view returns (address) { return seller; }
}

contract LenderHarness is LenderActor {
    function _lenderKeyEnvName()     internal pure override returns (string memory) { return "LENDER_KEY_test_other"; }
    function _lenderAddressEnvName() internal pure override returns (string memory) { return "LENDER_test_other"; }
    function exposed_addr() external view returns (address) { return lender; }
}

contract OtherActors_Test is Test {
    // Anvil default mnemonic: "test test test test test test test test test test test junk"
    // Index 1 -> 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    // Index 2 -> 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    // Index 3 -> 0x90F79bf6EB2c4f870365E785982E1f101E93b906
    // Index 4 -> 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
    // Index 5 -> 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc

    function test_poolAdmin_mnemonicIndex1() public {
        assertEq(new PoolAdminHarness().exposed_addr(), 0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    }

    function test_deployer_mnemonicIndex2() public {
        assertEq(new DeployerHarness().exposed_addr(), 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
    }

    function test_buyer_mnemonicIndex3() public {
        assertEq(new BuyerHarness().exposed_addr(), 0x90F79bf6EB2c4f870365E785982E1f101E93b906);
    }

    function test_seller_mnemonicIndex4() public {
        assertEq(new SellerHarness().exposed_addr(), 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
    }

    function test_lender_mnemonicIndex5() public {
        assertEq(new LenderHarness().exposed_addr(), 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc);
    }
}
