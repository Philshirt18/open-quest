# Add your own quest to Open Quest

A quest is any contract with **one function**:

```solidity
function check(address user) external view returns (bool); // has this wallet done it?
```

You write it, deploy it, register it. No permission, no form, no one to ask. Once registered, your quest
shows up in the **Community quests** list on the page and any app can read it from the registry.

It costs a few cents in USDC on Arc (about $0.003 for the registration, plus deploying your contract).

## 1. Write the quest (about 10 lines)

Copy [`src/examples/QuestTemplate.sol`](src/examples/QuestTemplate.sol), rename the contract and change the
one line that says `CHANGE ME`:

```solidity
contract MyQuest is IQuest {
    function check(address user) external view returns (bool) {
        return user.balance > 0; // your rule, e.g. "has any USDC"
    }
}
```

A fuller example that checks a token balance is [`HolderQuest`](src/examples/HolderQuest.sol).

### Rules your quest must follow

- **It is a read.** No state changes, no loops over long lists, nothing that can run out of gas.
- **It has 100,000 gas.** The registry reads your quest with that limit.
- **Only an exact `true` counts as done.** A revert, running out of gas, empty or odd return data, or `false`
  all show as "not done". That is by design, so nobody's quest can break anyone else's.
- **It cannot change the badge.** The badge depends only on the three built-in quests. Community quests are
  shown next to them, never counted in them.
- **Registration is public and permanent.** There is no way to remove a quest, and each contract address can be
  registered once. The name can be up to 64 bytes and the description up to 280 bytes.
- **Be honest in the name and description.** They are shown to everyone, as plain text.

## 2. Test it

Copy the pattern in [`test/QuestTemplate.t.sol`](test/QuestTemplate.t.sol): deploy your quest, register it
in a registry, check the status through `registry.isComplete(id, wallet)`.

```bash
forge test --match-contract MyQuestTest -vv
```

## 3. Deploy and register

Use a wallet with a little USDC on Arc. Put its key in `.env` as `PRIVATE_KEY=...` (never commit that file),
then load it:

```bash
set -a && source .env && set +a

# deploy your quest
forge create src/examples/MyQuest.sol:MyQuest --rpc-url arc_mainnet --private-key "$PRIVATE_KEY" --broadcast
# note the "Deployed to" address, then register it (dry run first: leave out --broadcast)
QUEST=0xYourQuestAddress NAME="My quest" DESCRIPTION="What to do, in one sentence." \
  forge script script/RegisterQuest.s.sol --rpc-url arc_mainnet --broadcast
```

The registry address is read from [`deployments/5042.json`](deployments/5042.json). To use another registry,
set `REGISTRY=0x...`.

Or do it by hand with `cast`:

```bash
cast send <QuestRegistry> "registerQuest(address,string,string)" 0xYourQuest "My quest" "What to do" \
  --rpc-url https://rpc.mainnet.arc.io --private-key "$PRIVATE_KEY"
```

Or use the **Register a quest** form on the page, which sends the same transaction from your wallet.

## 4. See it

Open the page and look under **Community quests**. Connect a wallet to see its status on your quest.

## Reading the registry from your own app

```js
// ethers v6
const registry = new ethers.Contract(REGISTRY, [
  "function questCount() view returns (uint256)",
  "function getQuest(uint256) view returns (tuple(address quest, address registrant, string name, string description))",
  "function isComplete(uint256, address) view returns (bool)",
], provider);

const n = await registry.questCount();
for (let id = 3n; id < n; id++) {            // ids 0-2 are the built-in quests
  const q = await registry.getQuest(id);
  console.log(q.name, await registry.isComplete(id, wallet));
}
```
