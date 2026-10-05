#!/usr/bin/env bash
# Plays the whole Open Quest journey on a LOCAL anvil chain and checks every step.
# Uses anvil's public test account #1 (no real funds). Run `anvil` and deploy first:
#   PRIVATE_KEY=<anvil key #0> forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
set -euo pipefail
export PATH="$PATH:$HOME/.foundry/bin"
RPC=http://127.0.0.1:8545
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80   # anvil #0 (public)
USER_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d       # anvil #1 (public)
USER=$(cast wallet address --private-key "$USER_KEY")
J=deployments/31337.json
get() { python3 -c "import json;print(json.load(open('$J'))['$1'])"; }
USDC=$(get usdc); REG=$(get registerQuest); DEP=$(get depositQuest); WD=$(get withdrawQuest)
REGISTRY=$(get questRegistry); BADGE=$(get questBadge); HOLDER_ID=$(get holderQuestId)
say() { printf '\n== %s\n' "$*"; }
send() { cast send --rpc-url "$RPC" --private-key "$USER_KEY" "$@" >/dev/null; }
call() { cast call --rpc-url "$RPC" "$@"; }
expect() { [ "$1" = "$2" ] && echo "   ok: $3 = $1" || { echo "   FAIL: $3 expected $2 got $1"; exit 1; }; }

say "Give the user 1 USDC (mock) so they can play"
cast send --rpc-url "$RPC" --private-key "$DEPLOYER_KEY" "$USDC" "mint(address,uint256)" "$USER" 1000000 >/dev/null
expect "$(call "$USDC" 'balanceOf(address)(uint256)' "$USER" | awk '{print $1}')" 1000000 "USDC balance"

say "Start: nothing done, badge locked"
expect "$(call "$REGISTRY" 'builtInProgress(address)(bool[3])' "$USER")" "[false, false, false]" "progress"

say "Claim too early must fail"
if cast send --rpc-url "$RPC" --private-key "$USER_KEY" "$REGISTRY" 'claimBadge()' >/dev/null 2>&1; then echo "   FAIL: early claim succeeded"; exit 1; else echo "   ok: early claim reverted"; fi

say "Quest 1: join"
send "$REG" 'join()'
expect "$(call "$REGISTRY" 'builtInProgress(address)(bool[3])' "$USER")" "[true, false, false]" "progress"

say "Quest 2: approve 0.01 USDC, then deposit"
send "$USDC" 'approve(address,uint256)' "$DEP" 10000
send "$DEP" 'deposit()'
expect "$(call "$REGISTRY" 'builtInProgress(address)(bool[3])' "$USER")" "[true, true, false]" "progress"
expect "$(call "$USDC" 'balanceOf(address)(uint256)' "$USER" | awk '{print $1}')" 990000 "USDC balance after deposit"

say "Quest 3: withdraw (funds come back)"
send "$DEP" 'withdraw()'
expect "$(call "$REGISTRY" 'builtInProgress(address)(bool[3])' "$USER")" "[true, true, true]" "progress"
expect "$(call "$USDC" 'balanceOf(address)(uint256)' "$USER" | awk '{print $1}')" 1000000 "USDC balance after withdraw"

say "Claim the badge"
send "$REGISTRY" 'claimBadge()'
TOKEN=$(cast to-dec "$USER")
expect "$(call "$BADGE" 'ownerOf(uint256)(address)' "$TOKEN")" "$USER" "badge owner"
expect "$(call "$BADGE" 'levelOf(uint256)(uint8)' "$TOKEN" | awk '{print $1}')" 3 "badge level"

say "Claiming again must fail; transferring the badge must fail"
if cast send --rpc-url "$RPC" --private-key "$USER_KEY" "$REGISTRY" 'claimBadge()' >/dev/null 2>&1; then echo "   FAIL: second claim succeeded"; exit 1; else echo "   ok: second claim reverted"; fi
OTHER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
if cast send --rpc-url "$RPC" --private-key "$USER_KEY" "$BADGE" 'transferFrom(address,address,uint256)' "$USER" "$OTHER" "$TOKEN" >/dev/null 2>&1; then echo "   FAIL: badge was transferred"; exit 1; else echo "   ok: transfer reverted (soulbound)"; fi

say "Third-party Holder quest (id $HOLDER_ID) shows status for this wallet"
expect "$(call "$REGISTRY" 'isComplete(uint256,address)(bool)' "$HOLDER_ID" "$USER")" true "holder quest (user holds 1 USDC)"

echo; echo "Whole journey passed."
