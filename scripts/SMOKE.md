# Local Smoke Test (Anvil)

End-to-end verification that the refactored scripts produce a working
protocol on a local anvil chain.

## Prerequisites

- `anvil` running with default mnemonic on chain id 31337.
- `MNEMONIC`, `GOVERNOR_KEY`, etc. unset (let scripts use the default test mnemonic).

## Steps

1. Start anvil in another terminal:

       anvil

2. Deploy singletons:

       forge script DeployIsleUSD       --rpc-url http://127.0.0.1:8545 --broadcast
       forge script DeployIsleGlobals   --rpc-url http://127.0.0.1:8545 --broadcast
       forge script DeployReceivable    --rpc-url http://127.0.0.1:8545 --broadcast

3. Bootstrap globals (each script prompts for the necessary values):

       forge script SetValidPoolAdmin       --rpc-url http://127.0.0.1:8545 --broadcast
       forge script SetValidPoolAsset       --rpc-url http://127.0.0.1:8545 --broadcast
       forge script SetValidReceivableAsset --rpc-url http://127.0.0.1:8545 --broadcast
       forge script SetProtocolFee          --rpc-url http://127.0.0.1:8545 --broadcast
       forge script SetIsleVault            --rpc-url http://127.0.0.1:8545 --broadcast

4. Deploy a market end-to-end:

       shell/deploy-market.sh ChargeSmith http://127.0.0.1:8545

5. Inspect the ledger:

       cat scripts/deployment.toml

   Expect a `[anvil]` section with `IsleGlobals`, `Receivable`, `IsleUSD`
   addresses and one `[[anvil.markets]]` entry named "ChargeSmith" with
   all five module addresses populated.

6. Reset between runs:

       echo "" > scripts/deployment.toml

## Pass criteria

- All `forge script` invocations complete with no revert.
- `deployment.toml` contains the expected sections after step 5.
- Step 6 produces a fresh empty ledger so the run can be repeated.
