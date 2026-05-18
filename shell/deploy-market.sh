#!/usr/bin/env bash
# Usage: shell/deploy-market.sh <market-name> <rpc-url>
#
# Chains the four module deployments that together stand up one market.
# Each forge invocation reads the market name from its own stdin so the
# Solidity-level vm.prompt receives the same value across steps.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <market-name> <rpc-url>" >&2
    exit 1
fi

NAME="$1"
RPC="$2"

echo "==> DeployPoolAddressesProvider"
printf '%s\n' "$NAME" | forge script DeployPoolAddressesProvider --rpc-url "$RPC" --broadcast

echo "==> DeployPoolConfigurator"
# This step prompts for additional values (poolAdmin, asset, name, symbol) — the
# operator must respond interactively beyond the first line. The wrapper feeds
# only the market name; remaining prompts come from the human.
printf '%s\n' "$NAME" | forge script DeployPoolConfigurator --rpc-url "$RPC" --broadcast

echo "==> DeployLoanManager"
printf '%s\n' "$NAME" | forge script DeployLoanManager --rpc-url "$RPC" --broadcast

echo "==> DeployWithdrawalManager"
printf '%s\n' "$NAME" | forge script DeployWithdrawalManager --rpc-url "$RPC" --broadcast

echo "==> Market '${NAME}' deployment complete."
