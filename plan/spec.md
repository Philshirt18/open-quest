---
doc: spec
status: approved
---

# Open Quest — Technical Spec

## How This Works, In Plain Language
Open Quest is a handful of small smart contracts on Arc plus one static web page. A **registry** contract keeps a list of quests. Each quest is a tiny contract that can answer one question: "has this wallet done the thing?" Three built-in quests (Join, Deposit 0.01 USDC, Withdraw) are fixed when the registry is deployed, and nobody can change them. When a wallet has completed all three, it can claim a **badge**, a non-transferable NFT, from the registry. Anyone can add their own quest to the list by registering any contract that answers that one question, and a hostile quest can't hurt anyone because the badge only depends on the three built-in ones. The web page just reads the chain and sends transactions from the visitor's own wallet. There is no backend and no database: all state lives on Arc, and the page is hosted for free on GitHub Pages. After each transaction the page works out the network fee in dollars from the transaction receipt and links to the Arc explorer.

## Stack and Why
- **Solidity 0.8.x + Foundry (forge, anvil, cast):** the contracts and tests, as the brief asked. Foundry is also how we run a local chain (anvil) and a deploy script. Docs: [book.getfoundry.sh](https://book.getfoundry.sh/). Foundry is not installed on this Mac yet; the build installs it with the official installer after asking.
- **OpenZeppelin Contracts v5:** audited building blocks for ERC-721, `ReentrancyGuard`, `SafeERC20` and `Strings`/`Base64`. Docs: [docs.openzeppelin.com/contracts/5.x](https://docs.openzeppelin.com/contracts/5.x/). Tradeoff: a bigger dependency than hand-written code, in exchange for far less risk.
- **Plain HTML + CSS + JavaScript (ES modules), ethers.js v6 from a CDN, no build step:** as the brief asked. Docs: [docs.ethers.org/v6](https://docs.ethers.org/v6/). Tradeoff: no framework conveniences. The CDN version is pinned and checked in the build.
- **GitHub Pages:** free static hosting from the `docs/` folder of the repo. Docs: [docs.github.com/pages](https://docs.github.com/en/pages).
- **Arc network:** all values come from the official Arc docs. See **Arc Network Values** below.

### Arc Network Values
All live in one file, `docs/config.js`, each with its source. Checked on 2026-10-05 against the live RPC servers (`eth_chainId`).

| Value | Mainnet | Testnet | Source |
|---|---|---|---|
| Name | Arc | Arc Testnet | [Connect to Arc](https://docs.arc.io/arc/references/connect-to-arc) |
| Chain ID | 5042 (0x13b2) | 5042002 (0x4cef52) | same page; confirmed by `eth_chainId` on each RPC |
| RPC URL | https://rpc.mainnet.arc.io | https://rpc.testnet.arc.io | same page |
| Explorer | https://explorer.arc.io | https://explorer.testnet.arc.io | same page |
| Native currency | USDC, 18 decimals | USDC, 18 decimals | same page |
| USDC (ERC-20 interface) | 0x3600000000000000000000000000000000000000, 6 decimals | same address, 6 decimals | [Contract addresses](https://docs.arc.io/arc/references/contract-addresses) |
| Faucet | none | https://faucet.circle.com | Connect to Arc page |

Two things from the docs that matter here: native gas USDC uses **18 decimals** while the USDC ERC-20 interface uses **6 decimals**, and both share the same underlying balance. There is also a fee floor of 20 Gwei `maxFeePerGas`.

## Where It Runs, Deploys, and How Someone Tries It
- **Run the tests:** `forge test -vv`
- **Local chain and local deploy (rehearsal 1):** `anvil` in one terminal; `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast` in another (uses anvil's public test key and a mock USDC; no real funds).
- **See the page locally:** `python3 -m http.server 8000 --directory docs`, then open `http://localhost:8000`.
- **Testnet rehearsal (rehearsal 2):** with a fresh throwaway deployer key in `.env` and testnet USDC from the faucet: `forge script script/Deploy.s.sol --rpc-url arc_testnet --broadcast`.
- **Mainnet deploy (done by the user, never by the agent without asking):** the same script with `--rpc-url arc_mainnet`. The agent gives the exact commands; the user runs them.
- **Deploy target for the page:** GitHub Pages, branch `main`, folder `/docs`.
- **Repository (public):** https://github.com/Philshirt18/open-quest
- **Live page:** https://philshirt18.github.io/open-quest/ (default network: Arc mainnet; `?network=testnet` for the rehearsal deployment). Shipped 2026-10-05; verified against mainnet.
- **To update the page:** commit to `main`; Pages rebuilds from `docs/` in about a minute.
- **Environment variables (names only, placeholders in `.env.example`):**
  - `PRIVATE_KEY` — deployer key. Never committed; `.env` is git-ignored. Never typed in chat.
  - `ARC_MAINNET_RPC_URL`, `ARC_TESTNET_RPC_URL` — filled from the official values above.
  - `USDC_ADDRESS` — optional override; defaults to the official address on Arc networks.
- **After each deploy:** the script prints the addresses and the build writes them into `docs/config.js` and the README (separate entries for local, testnet and mainnet).

## Look and Feel
Implements `design.md` (approved). Carried into code as:
- `docs/style.css` starts with CSS variables (tokens) for light and dark: `--bg`, `--surface`, `--text`, `--muted`, `--primary` (#4D8EE9), `--accent` (#5FBFFF), `--success`, `--warning`, `--error`, `--radius-card: 16px`, `--radius-btn: 10px`, with a dark set under `@media (prefers-color-scheme: dark)`.
- Fonts: Google Fonts link for Space Grotesk (300, 400, 500); system monospace for addresses, hashes and code.
- 8px spacing grid, content column about 720px, single column on phones, 44px minimum touch targets, visible `:focus-visible` outlines, `prefers-reduced-motion` respected, status shown with icon and text, never color alone.

## Core Journey Through the System
1. **Visitor opens the page** (static files from GitHub Pages). The page shows the headline, the cost note, and a Connect button. Nothing touches the chain yet.
2. **Connect:** the page asks the browser wallet for accounts (`eth_requestAccounts`). It checks the wallet's chain ID against `docs/config.js`; if it differs it shows the banner and, on click, asks the wallet to switch (`wallet_switchEthereumChain`) or add (`wallet_addEthereumChain`) the network.
3. **Load progress:** the page reads `builtInProgress(user)` from the registry (one call, three booleans), plus whether the badge is claimed, using a read-only provider on the official RPC. Cards render as done, active or locked.
4. **Join:** wallet sends `RegisterQuest.join()`. The page waits for the receipt, computes the fee, shows the explorer link, and reloads progress.
5. **Deposit:** step one `USDC.approve(DepositQuest, 0.01 USDC)` for exactly the amount, step two `DepositQuest.deposit()`, which pulls 0.01 USDC with `transferFrom`.
6. **Withdraw:** wallet sends `DepositQuest.withdraw()`; the contract returns the 0.01 USDC to the depositor. `WithdrawQuest.check(user)` becomes true.
7. **Claim:** wallet sends `QuestRegistry.claimBadge()`. The registry checks the three built-in quests, then asks the badge contract to mint the badge to the caller with level 3. The page then reads the badge and shows it.
8. **Add your own quest section:** static code example, plus a live read of the Holder example quest through `QuestRegistry.isComplete(id, user)`.

## Components

### IQuest
The one-function interface every quest implements: `check(address user) external view returns (bool)`. Implements `prd.md > Registry (open registration)`.

### QuestRegistry
Holds the list of registered quests (`id`, quest address, registrant, name, description). The three built-in quests are registered as ids 0, 1 and 2 in the constructor and can never be changed or removed. The constructor also deploys the `QuestBadge` and remembers it, so no later "set badge" step exists and there is no owner or admin.
- `registerQuest(address quest, string name, string description) returns (uint256 id)` — callable by anyone. Rejects: zero address, an address with no contract code, an already registered address, a name over 64 bytes, a description over 280 bytes. Emits `QuestRegistered`. It does not call the quest.
- `questCount()`, `getQuest(id)` — read the list.
- `isComplete(id, user)` — read-only; reads the quest's `check` with a gas-limited low-level `staticcall` that copies at most 32 bytes and accepts only exactly `true`, so a hostile or broken quest (reverts, burns gas, returns nothing, junk or too much data) returns false and never makes the call revert.
- `builtInProgress(user) returns (bool[3])` — the three built-in checks (trusted code).
- `claimBadge()` — `nonReentrant`; requires all three built-in checks true (reverts `QuestNotComplete(id)` naming the first missing one); requires no badge yet (reverts `AlreadyClaimed`); mints with level 3. Third-party quests are never called in a transaction.

Implements `prd.md > Registry (open registration)`, `prd.md > Claim badge`.

### RegisterQuest
`join()` records `joined[msg.sender] = true` and emits `Joined`; a second call reverts `AlreadyJoined`. `check(user)` returns `joined[user]`. Implements `prd.md > Quest 1: Join`.

### DepositQuest
The only contract that ever holds user funds. Holds each depositor's 0.01 USDC (10,000 units at 6 decimals) and gives it back to that depositor on request.
- `deposit()` — `nonReentrant`; one deposit per wallet ever (reverts `AlreadyDeposited`); records first, then pulls the USDC with `SafeERC20.safeTransferFrom`.
- `withdraw()` — `nonReentrant`; reverts `NothingToWithdraw` if there is no live deposit; sets the balance to zero and records `withdrawn[user] = true` first, then sends the USDC back with `SafeERC20.safeTransfer`. Callable by the depositor at any time, so funds do not depend on any other contract.
- `check(user)` returns "has deposited". There is no owner, no admin, no pause, no upgrade, and no function that moves funds to anyone but the depositor.

Implements `prd.md > Quest 2: Deposit 0.01 USDC`.

### WithdrawQuest
A view-only quest with no funds: `check(user)` returns `DepositQuest.withdrawn(user)`, which is only true after a real deposit followed by a real withdrawal. The page's Withdraw button calls `DepositQuest.withdraw()`. **Decision:** the withdraw action lives next to the money so that it can never be blocked by another contract; `WithdrawQuest` is the checker. Implements `prd.md > Quest 3: Withdraw`.

### QuestBadge
Soulbound ERC-721 (OpenZeppelin). The token id is the owner's address as a number, so one wallet can only ever hold one badge. Only the registry can mint (the registry address is fixed in the constructor). Transfers revert: `_update` rejects everything except minting, and approvals have no effect. Implements ERC-5192 `locked(id)` returning true and the `Locked` event. Stores the level per token; `svgOf(tokenId)` draws the artwork on-chain (arc with one ticked node per quest, the level, "built on Arc", the owner's short address) and `tokenURI` returns on-chain JSON with that image, so the badge shows in wallets without hosting anything. Uses `_mint` (not `_safeMint`) so no receiver callback can re-enter. Implements `prd.md > Claim badge`.

### HolderQuest (example third-party quest)
About 10 lines: `check(user)` returns true if the user's USDC balance is at least 1 USDC. Deployed and registered with the same public `registerQuest` call anyone would use. Appears only in the "Add your own quest" section and the README; it never affects the badge. Implements `prd.md > Add your own quest`.

### Deploy script (`script/Deploy.s.sol`)
Reads `PRIVATE_KEY` from the environment. Deploys the three quests, the registry (which creates the badge), and the Holder example, then registers the Holder example through `registerQuest`. On the local chain (anvil, id 31337) it first deploys a `MockUSDC`. On Arc networks it uses the official USDC address. Prints all addresses. Never contains a key.

### Frontend: wallet and network (`docs/app.js`)
Connect button, wallet address, banner for wrong network, friendly state for no wallet, and a clear message when the config has no addresses for the connected network. Implements `prd.md > Connect wallet and network`.

### Frontend: quests and feedback (`docs/app.js`)
Renders the three cards from on-chain state, enforces the page-only quest order, drives the two-step Deposit, shows "Waiting for confirmation", rejected/failed/slow states, and after each transaction shows the fee and explorer link. Fee in dollars = `gasUsed × effectiveGasPrice ÷ 10^18` (native USDC has 18 decimals), shown with up to 4 decimals ("less than $0.0001" if smaller). USDC amounts for deposits use 6 decimals. Reads progress on load so a reopened page shows the true state. Implements `prd.md > Quest sequence`, `Quest 1`, `Quest 2`, `Quest 3`, `Transaction feedback`.

### Frontend: community quests and register form (`docs/index.html`, `docs/app.js`) — added after the first review
Reads `questCount()` and `getQuest(id)` for ids 3 and up (newest first, ten at a time) and `isComplete(id, wallet)` for the connected wallet. Text from the chain goes into the page only through `textContent` after removing control and text-direction characters. The form validates input, previews `check(wallet)` with a gas limit, re-checks the network and that the address is a contract that is not yet registered, then sends `registerQuest`. Implements the new PRD sections `Community quests` and `Register a quest`.

### Builder kit — added after the first review
`src/examples/QuestTemplate.sol`, `script/RegisterQuest.s.sol` (dry run without `--broadcast`), `test/QuestTemplate.t.sol`, `BUILDERS.md`.

### Frontend: cost note, badge, add-your-own (`docs/index.html`, `docs/app.js`)
The cost note before connecting ("less than $0.05 of USDC covers everything"; the exact number is confirmed from measured fees). Claim button locked with "Complete all 3 quests" until ready, the badge view with its level, and the "Add your own quest" section with the code example and a live Holder quest status. Implements `prd.md > Cost note`, `Claim badge`, `Add your own quest`.

## File Structure
```
.                          (project root; the folder is "Arc ")
  foundry.toml             — Foundry settings, Solidity version, RPC aliases arc_mainnet / arc_testnet from env
  .env.example             — variable names with empty placeholders (never real values)
  .gitignore               — already ignores .env and .env.*; the build adds out/ and cache/
  AGENTS.md                — project rules for the AI helper
  README.md                — what it does, live link, addresses, how it uses Arc, add-a-quest, what's next
  src/
    IQuest.sol             — the one-function quest interface
    QuestRegistry.sol      — open registry, built-in progress, badge claim
    QuestBadge.sol         — soulbound ERC-721 with level
    quests/
      RegisterQuest.sol    — join()
      DepositQuest.sol     — deposit(), withdraw(); holds funds
      WithdrawQuest.sol    — checker for "withdrew after depositing"
    examples/
      HolderQuest.sol      — the ~10-line third-party example
  test/
    RegisterQuest.t.sol    — join, double join
    DepositQuest.t.sol     — deposit, withdraw, withdraw before deposit, reentrancy, double deposit
    QuestRegistry.t.sol    — register, claim too early, claim twice, hostile quest, third-party quest
    QuestBadge.t.sol       — soulbound transfers and approvals revert, level
    mocks/MockUSDC.sol     — 6-decimal test token (also used by local deploy)
  script/
    Deploy.s.sol           — deploys and registers everything, key from environment
  docs/                    — the website served by GitHub Pages
    index.html             — the page
    style.css              — design tokens and styles
    app.js                 — wallet, quests, fees, badge
    config.js              — SINGLE config: network values (with sources), contract addresses, ABIs
  lib/                     — forge-std and openzeppelin-contracts (installed with forge)
  plan/                    — brief, scope, prd, design, spec, checklist
```

## Data Model
Everything is on-chain: the quest list and per-wallet "joined", "deposited" and "withdrawn" flags, the held deposits, and the badge. The page stores nothing (no database, no cookies, no local storage required). Returning visitors see their real state read from the chain.

## AGENTS.md
Short project rules the build writes to `AGENTS.md`:
- Stack: Solidity + Foundry + OpenZeppelin v5; static page in `docs/` with ethers v6, no build step.
- Commands: `forge test -vv`, `forge build`, `anvil`, `forge script script/Deploy.s.sol ...`, `python3 -m http.server 8000 --directory docs`.
- Never hardcode or commit keys; `.env` stays git-ignored; never ask for or print private keys.
- Never guess Arc network values; they live only in `docs/config.js` with sources.
- Never run a mainnet deployment or any mainnet transaction without the user's explicit yes.
- No admin powers over user funds; no new features beyond `plan/prd.md`.
- Keep contracts small, readable and commented; run the tests after every change.
- The project is called "Open Quest". Say "built on Arc"; never put "Arc" in the product name or alter the Arc logo.

## External Services
- **Arc RPC and explorer** (public, free): `rpc.mainnet.arc.io`, `explorer.arc.io`; testnet equivalents. No account needed.
- **Circle faucet** for testnet USDC: https://faucet.circle.com (the user claims it in their own browser).
- **GitHub** (public repo and Pages) and **a browser wallet** (the user's own).
- **CDN for ethers.js and Google Fonts** for the page; no keys needed.
- No paid services.

## Failure Modes
- **No wallet / wrong network / not enough USDC / rejected / failed / slow transaction:** handled as in `prd.md > Connect wallet and network`, `Quest 2`, `Transaction feedback`.
- **RPC down or slow:** the page shows "Can't reach Arc right now. Try again." with a retry button; it never shows false "done" states.
- **Hostile or broken third-party quest:** `isComplete` returns false (gas-limited low-level call, only an exact `true` counts); the badge never depends on it.
- **USDC issuer restrictions:** USDC is issued by Circle, which can block an address at the token level. If a wallet were blocked, its withdrawal could revert. This is outside our contracts' control and is stated in the README.
- **Config missing addresses for the connected network:** the page shows a clear message instead of failing silently.

## Simplifications
- Quest order is enforced by the page only; the contracts allow any order (the badge still needs all three checks).
- One deposit per wallet, ever. There is no re-deposit after withdrawing.
- The registry list is read by the page one quest at a time; no indexer or pagination (fine for a small first version).
- No contract upgradeability, no pause switch, no owner: simpler and safer.
- Third-party quests are shown but never count toward the badge (decided for lowest risk).

## Decisions and Open Issues
**Decisions made**
- Name changed from "Arc Quest" to "Open Quest" because the Arc brand toolkit does not allow "Arc" in a product name without qualification ([toolkit](https://arc.io/brand-guidelines-and-partner-toolkit)). Arc appears only in descriptions.
- Lowest-risk badge design: level fixed at 3, third-party quests never counted.
- Funds live only in `DepositQuest`, which has its own `withdraw()`; `WithdrawQuest` is a checker. This slightly differs from the brief's wording ("WithdrawQuest: user withdraws") for safety.
- The registry deploys the badge itself, so no owner or setup step exists.
- Approve exactly 0.01 USDC rather than an unlimited allowance.

**Open issues (the build checks these)**
- **Foundry is not installed** on this Mac; the build installs it after asking.
- **Dollar-fee display accuracy** (the user's useful unknown): the build compares the computed fee against the real fee in the wallet and explorer on testnet before trusting the display.
- **Verifying the contracts on the Arc explorer** (for credibility): check whether the explorer supports `forge verify-contract` and how.
- **Behavior of the real USDC contract on Arc** (approve and transferFrom through the 6-decimal interface at `0x3600…0000`): confirm with a fork test or a real testnet run before mainnet.
- **How to check the page without a wallet extension in the build environment:** use a small dev-only test provider kept outside `docs/`, or the user's own wallet on testnet.
- **ethers CDN version** to pin (and whether to add a subresource integrity hash): decided in the build.
- **GitHub repo name and the user's public builder profile** (GitHub, X, or Farcaster) for the submission: asked in `kit-7-ship`.
- **Mainnet USDC for the deployer wallet** (a few cents for gas): the user prepares it; target mainnet deploy by Oct 11-12 for a buffer before Oct 14, 23:59 ET.
