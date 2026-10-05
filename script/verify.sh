#!/usr/bin/env bash
# Verifies all Open Quest contracts on the Arc explorer (Blockscout) so anyone can read the source.
# Usage: ./script/verify.sh <chainId>     (5042002 testnet, 5042 mainnet)
# Source: https://docs.arc.io/arc/tutorials/deploy-on-arc
set -uo pipefail
export PATH="$PATH:$HOME/.foundry/bin"
CHAIN=${1:?usage: verify.sh <chainId>}
case "$CHAIN" in
  5042002) URL=https://explorer.testnet.arc.io/api/;;
  5042)    URL=https://explorer.arc.io/api/;;
  *) echo "unsupported chain"; exit 1;;
esac
J=deployments/$CHAIN.json
get() { python3 -c "import json;print(json.load(open('$J'))['$1'])"; }
USDC=$(get usdc); REG=$(get registerQuest); DEP=$(get depositQuest); WD=$(get withdrawQuest)
REGISTRY=$(get questRegistry); BADGE=$(get questBadge); HOLDER=$(get holderQuest)
v() { # address, contract path:name, [constructor args]. Retries because the explorer rate-limits.
  echo "--- $2"
  local out i
  for i in 1 2 3 4; do
    if [ -n "${3:-}" ]; then
      out=$(forge verify-contract "$1" "$2" --chain-id "$CHAIN" --verifier blockscout --verifier-url "$URL" --constructor-args "$3" --watch 2>&1)
    else
      out=$(forge verify-contract "$1" "$2" --chain-id "$CHAIN" --verifier blockscout --verifier-url "$URL" --watch 2>&1)
    fi
    if echo "$out" | grep -qE "Pass - Verified|already verified"; then echo "   verified"; sleep 15; return; fi
    echo "   attempt $i not done yet: $(echo "$out" | grep -E "Error|message=" | head -1)"; sleep 30
  done
  echo "   FAILED after retries"
}
v "$REG"  src/quests/RegisterQuest.sol:RegisterQuest
v "$DEP"  src/quests/DepositQuest.sol:DepositQuest "$(cast abi-encode 'constructor(address)' "$USDC")"
v "$WD"   src/quests/WithdrawQuest.sol:WithdrawQuest "$(cast abi-encode 'constructor(address)' "$DEP")"
v "$HOLDER" src/examples/HolderQuest.sol:HolderQuest "$(cast abi-encode 'constructor(address,uint256)' "$USDC" 1000000)"
v "$BADGE" src/QuestBadge.sol:QuestBadge
# The registry's constructor takes the three built-in quests with names and descriptions.
ARGS=$(cast abi-encode 'constructor(address[3],string[3],string[3])' "[$REG,$DEP,$WD]" '["Join Open Quest","Deposit 0.01 USDC","Withdraw your deposit"]' '["Say hello on Arc: call join() once.","Deposit 0.01 USDC. You can take it back at any time.","Take your 0.01 USDC deposit back."]')
v "$REGISTRY" src/QuestRegistry.sol:QuestRegistry "$ARGS"
