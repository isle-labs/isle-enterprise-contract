// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { PoolAddressesProvider } from "contracts/PoolAddressesProvider.sol";

import { GovernorActor } from "scripts/actors/Governor.s.sol";
import { MarketRecord } from "scripts/Base.s.sol";

contract SetPoolConfiguratorImpl is GovernorActor {
    function run() public {
        MarketRecord memory market = promptMarket();
        address newImpl = promptAddress("New PoolConfigurator implementation address");
        string memory raw = promptString("Init calldata (0x-prefixed hex; empty for no init)");
        bytes memory params = bytes(raw).length == 0 ? bytes("") : vm.parseBytes(raw);

        _set(PoolAddressesProvider(market.PoolAddressesProvider), newImpl, params);
    }

    function _set(PoolAddressesProvider provider, address impl, bytes memory params) internal asGovernor {
        provider.setPoolConfiguratorImpl(impl, params);
    }
}
