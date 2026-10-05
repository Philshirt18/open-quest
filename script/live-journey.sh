#!/usr/bin/env bash
# Plays the Open Quest journey on a REAL network (use Arc Testnet) with the wallet in .env,
# and compares the fees computed from receipts with the real balance change.
# Usage: ./script/live-journey.sh <chainId>      (5042002 = Arc Testnet)
# Safety: refuses to run on Arc mainnet (5042). Mainnet is only ever done by hand by the owner.
set -euo pipefail
export PATH="$PATH:$HOME/.foundry/bin"
CHAIN=${1:?usage: live-journey.sh <chainId>}
[ "$CHAIN" = "5042" ] && { echo "Refusing to run on mainnet."; exit 1; }
set -a; . ./.env; set +a
case "$CHAIN" in 5042002) RPC=$ARC_TESTNET_RPC_URL;; *) echo "unsupported chain"; exit 1;; esac
J=deployments/$CHAIN.json
get() { python3 -c "import json;print(json.load(open('$J'))['$1'])"; }
USDC=$(get usdc); REG=$(get registerQuest); DEP=$(get depositQuest); REGISTRY=$(get questRegistry); BADGE=$(get questBadge); HID=$(get holderQuestId)
ME=$(cast wallet address --private-key "$PRIVATE_KEY")
TOTAL_FEE=0
step() { # name, then cast send args
  local name=$1; shift
  local out; out=$(cast send --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json "$@")
  local gas price status hash fee
  gas=$(python3 -c "import json,sys;print(int(json.loads(sys.argv[1])['gasUsed'],16))" "$out")
  price=$(python3 -c "import json,sys;print(int(json.loads(sys.argv[1])['effectiveGasPrice'],16))" "$out")
  status=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['status'])" "$out")
  hash=$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['transactionHash'])" "$out")
  fee=$((gas*price))
  TOTAL_FEE=$((TOTAL_FEE+fee))
  printf '%-22s status=%s gas=%-7s price=%s gwei fee=$%s  tx=%s\n' "$name" "$status" "$gas" "$(python3 -c "print($price/1e9)")" "$(python3 -c "print(f'{$fee/1e18:.6f}')")" "$hash"
}
NATIVE_BEFORE=$(cast balance "$ME" --rpc-url "$RPC")
echo "Wallet $ME on chain $CHAIN"
echo "progress before: $(cast call --rpc-url "$RPC" "$REGISTRY" 'builtInProgress(address)(bool[3])' "$ME")"
step "join"        "$REG" 'join()'
step "approve 0.01"  "$USDC" 'approve(address,uint256)' "$DEP" 10000
step "deposit"     "$DEP" 'deposit()'
step "withdraw"    "$DEP" 'withdraw()'
step "claimBadge"  "$REGISTRY" 'claimBadge()'
NATIVE_AFTER=$(cast balance "$ME" --rpc-url "$RPC")
REAL=$((NATIVE_BEFORE-NATIVE_AFTER))
echo
echo "sum of fees from receipts : $TOTAL_FEE  (= \$$(python3 -c "print(f'{$TOTAL_FEE/1e18:.6f}')"))"
echo "real balance change       : $REAL  (= \$$(python3 -c "print(f'{$REAL/1e18:.6f}')"))"
[ "$TOTAL_FEE" = "$REAL" ] && echo "MATCH: fee computed from receipts equals the real balance change" || echo "MISMATCH"
echo "progress after: $(cast call --rpc-url "$RPC" "$REGISTRY" 'builtInProgress(address)(bool[3])' "$ME")"
TOKEN=$(cast to-dec "$ME")
echo "badge owner: $(cast call --rpc-url "$RPC" "$BADGE" 'ownerOf(uint256)(address)' "$TOKEN")  level: $(cast call --rpc-url "$RPC" "$BADGE" 'levelOf(uint256)(uint8)' "$TOKEN")"
echo "holder quest status: $(cast call --rpc-url "$RPC" "$REGISTRY" 'isComplete(uint256,address)(bool)' "$HID" "$ME")"
