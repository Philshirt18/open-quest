---
doc: checklist
status: approved
---
<!-- status: `draft` until the user approves the build order, then `approved`.
     The field labels below are a machine contract: reproduce them verbatim.
     Tick `- [ ]` → `- [x]` immediately after a slice is verified and committed. -->

# Build Checklist

## Slices

- [x] **1. Project setup and the open registry (the kernel)**
  - Becomes usable: anyone can register a third-party quest in the registry (in tests), and a hostile quest can't break reading it.
  - Why now: the open registry is the kernel, so it comes first. Setup (git, Foundry, OpenZeppelin, `AGENTS.md`) lives inside this slice.
  - PRD ref: `prd.md > Registry (open registration)`, `prd.md > Add your own quest`
  - Spec ref: `spec.md > IQuest`, `spec.md > QuestRegistry`, `spec.md > HolderQuest (example third-party quest)`
  - Build: `git init`; install Foundry; `forge init`; add OpenZeppelin v5 and forge-std; `foundry.toml`, `.env.example`, extend `.gitignore` (out/, cache/); `AGENTS.md` and `CLAUDE.md`; `IQuest`; `QuestRegistry` with registration rules and `isComplete` (gas-limited try/catch); `HolderQuest`; first tests including a hostile quest.
  - Verify (mechanical): `forge build` and `forge test -vv` pass: register a third-party quest, rejected cases (zero address, no code, duplicate, name or description too long), hostile quest returns false.
  - Try it yourself: run `forge test -vv` and read the test names; each one describes a behavior in plain words.
  - Commit: `feat: project setup and open quest registry`

- [x] **2. The three quests, the soulbound badge and claiming**
  - Becomes usable: in tests, a wallet joins, deposits, withdraws and claims a soulbound badge; every wrong move is rejected.
  - Why now: the second half of the contracts, which is the money-handling part, so the riskiest code gets the most testing early.
  - PRD ref: `prd.md > Quest 1: Join`, `Quest 2: Deposit 0.01 USDC`, `Quest 3: Withdraw`, `Claim badge`
  - Spec ref: `spec.md > RegisterQuest`, `DepositQuest`, `WithdrawQuest`, `QuestBadge`, `QuestRegistry`
  - Build: `RegisterQuest`, `DepositQuest`, `WithdrawQuest`, `QuestBadge`, `claimBadge` and `builtInProgress` in the registry, `MockUSDC`, all remaining tests.
  - Verify (mechanical): `forge test -vv` covers: each quest's happy path, double join, withdraw before deposit, double deposit, claim too early, claim twice, soulbound transfer and approval revert, reentrancy attempt, third-party quest registered. Also `forge test --gas-report` and `forge coverage` to see nothing is untested.
  - Try it yourself: run `forge test -vv`; I walk you through the list and explain what each test proves.
  - Commit: `feat: built-in quests, soulbound badge and claiming`

- [x] **3. Deploy script and local deployment**
  - Becomes usable: one command deploys everything to a local chain (anvil), and you can play through the whole journey with `cast` commands.
  - Why now: proves the deploy path with no real funds before the unfamiliar parts.
  - PRD ref: `prd.md > Core Journey`
  - Spec ref: `spec.md > Deploy script (script/Deploy.s.sol)`, `spec.md > Where It Runs, Deploys, and How Someone Tries It`
  - Build: `script/Deploy.s.sol` (key from `PRIVATE_KEY`, mock USDC on local chain, registers the Holder quest), an addresses output file, and a local walkthrough script.
  - Verify (mechanical): start `anvil`, run the deploy script, then join, deposit, withdraw and claim with `cast`; read back the badge level (3) and confirm a transfer reverts.
  - Try it yourself: run the same anvil and deploy commands in your terminal and see the addresses printed.
  - Commit: `feat: deploy script and local deployment`

- [x] **4. Testnet rehearsal with real USDC**
  - Becomes usable: the contracts are live on Arc Testnet, and the whole journey works with the real USDC contract.
  - Why now: the biggest unknowns (real USDC behavior, fee numbers, explorer links) come before any frontend depends on them. You prepare a throwaway deployer key and faucet funds; I never see the key.
  - PRD ref: `prd.md > Transaction feedback`, `prd.md > Cost note`
  - Spec ref: `spec.md > Decisions and Open Issues` (real USDC, fee accuracy, explorer verification)
  - Build: put the key in `.env` (you do it), deploy to testnet, run the journey with `cast`, measure real fees, try `forge verify-contract` on the explorer, and record the testnet addresses in `docs/config.js` and the README.
  - Verify (mechanical): the explorer shows the contracts and transactions; measured gas times price gives the dollar fee per action; withdraw returns the 0.01 USDC.
  - Try it yourself: open your deployed registry on the testnet explorer and see the badge.
  - Commit: `feat: testnet deployment and measured fees`

- [x] **5. The page: connect, network, progress and look**
  - Becomes usable: you open the page, connect, switch to Arc, and see your real quest status and the cost note, in the agreed design.
  - Why now: reading chain state is lower risk than sending transactions, and sets up the page for slice 6.
  - PRD ref: `prd.md > Connect wallet and network`, `Cost note`, `Quest sequence`
  - Spec ref: `spec.md > Frontend: wallet and network`, `Look and Feel`, `Frontend: cost note, badge, add-your-own`
  - Build: `docs/index.html`, `style.css` (design tokens, light and dark), `config.js` (single config with sources), `app.js` (connect, banner, read progress, cards in done, active and locked states).
  - Verify (mechanical): load the page from a local server; no console errors; screenshots at phone and desktop width compared with `design.md`; all states checked with a test wallet provider.
  - Try it yourself: open `http://localhost:8000` with your wallet and see your quests.
  - Commit: `feat: page with wallet connection and quest progress`

- [x] **6. The page: quests, fees, badge and "Add your own quest"**
  - Becomes usable: you complete the whole journey on the page, see fees in dollars and explorer links, claim and see your badge, and read the add-a-quest section with the live Holder quest.
  - Why now: the full journey, built on top of working reads.
  - PRD ref: `prd.md > Quest 1`, `Quest 2`, `Quest 3`, `Transaction feedback`, `Claim badge`, `Add your own quest`
  - Spec ref: `spec.md > Frontend: quests and feedback`, `Frontend: cost note, badge, add-your-own`
  - Build: transaction buttons including the two-step deposit, waiting, rejected and failed states, fee in dollars, explorer link, claim button and badge view, the "Add your own quest" section.
  - Verify (mechanical): run the journey on testnet through the page; compare the fee shown with the explorer; error states with a rejected transaction; screenshots at phone and desktop; no console errors.
  - Try it yourself: do the whole journey on testnet with your own wallet.
  - Commit: `feat: full quest journey on the page`

- [x] **7. README and mainnet launch kit**
  - Becomes usable: a judge can understand the project in two minutes, and you have the exact mainnet commands.
  - Why now: all that's left is documentation and the mainnet step you run yourself.
  - PRD ref: `prd.md > Overview`, `prd.md > Add your own quest`
  - Spec ref: `spec.md > Where It Runs, Deploys, and How Someone Tries It`, `spec.md > Failure Modes`
  - Build: README (what it does, live demo placeholder, addresses, how it uses Arc, add-a-quest in about 10 lines, risks and USDC issuer note, what's next), exact mainnet deploy commands. I do not run the mainnet deployment; you do, and then I write the mainnet addresses into `docs/config.js` and the README.
  - Verify (mechanical): all README commands run as written on a fresh clone; links work; tests pass.
  - Try it yourself: read the README as if you were a judge; then run the mainnet commands I give you.
  - Commit: `docs: README and mainnet launch kit`

## Final Review

- [x] Project started as the spec describes; relevant checks pass
- [x] Owner deploys to Arc mainnet with the README commands; addresses go into `docs/config.js` (mainnet contracts, default network = mainnet) and the README table; user completes the journey once on mainnet (target: Oct 11-12, deadline Oct 14, 23:59 ET)
- [x] User explored the running app and gave feedback
- [x] Agreed fixes implemented, verified, committed (none requested: the user reported that everything worked)
- [x] User confirmed the first version is ready to ship

## Revisions

<!-- One bullet per plan change: what changed, and what the build discovered. -->
- Slice 1: `forge install` could not add git submodules because the project folder name ends with a space, so dependencies were installed with `--no-git` and only their Solidity sources are committed (see `.gitignore`).
- Slice 1: the registry constructor takes the three built-in quests with their names and descriptions and registers them as ids 0-2 (the badge is added in slice 2).
- Slice 2: the reentrancy test passes even without `nonReentrant` because `withdraw()` zeroes the balance before sending funds (checks-effects-interactions). Both layers stay in; the test proves the attack fails, not the guard alone.
- Slice 4: deployed to Arc Testnet (chain 5042002) with the real USDC at 0x3600...0000 and ran the full journey. Fee computed from receipts (gasUsed x effectiveGasPrice / 1e18) matched the real balance change exactly. Whole journey costs about $0.011 in fees (join $0.0014, approve $0.0015, deposit $0.0030, withdraw $0.0019, claim $0.0031), the 0.01 USDC deposit is returned. Cost note on the page can say "less than $0.05".
- Slice 4: the explorer is Blockscout; `forge verify-contract --verifier blockscout` works but the explorer rate-limits. 4 of 6 testnet contracts are verified (RegisterQuest, DepositQuest, QuestBadge, QuestRegistry); WithdrawQuest and HolderQuest kept failing with "Too many requests". `script/verify.sh` retries; the manual fallback is the explorer's verification page. Not blocking.
- Slice 4: `docs/config.js` was created here (earlier than planned) so the testnet addresses live in the single config file; slice 5 builds the page around it.
- Slice 5: ethers pinned to 6.17.0 from cdnjs with a SHA-384 integrity hash computed from the downloaded file. Added a Content-Security-Policy meta tag (scripts only from the page itself and cdnjs; network requests only to Arc's public RPCs). If a later slice needs another host (for example a different RPC), update the policy in `docs/index.html`.
- Slice 5: design colours darkened for WCAG AA after measuring contrast (muted text #5A6A80, success #15803D); recorded in `plan/design.md`. Buttons use #2F6FCF, the brand blue #4D8EE9 stays for borders and hover.
- Slice 5: the page attaches wallet listeners the first time it sees a wallet (some wallets inject late). All states were checked with an injected test wallet: no wallet, wrong network then switch, fresh wallet, finished wallet (real testnet data), mainnet not configured, unreachable network with retry.
- Slice 6: Arc's RPC prunes old history ("pruned history unavailable"; only roughly the last 5,000 blocks), so a reopened page cannot rebuild old transactions from event logs. The page shows each transaction's dollar fee and explorer link right after it happens and remembers them in this browser (localStorage, per wallet and network). On another device a finished quest shows "Done" and the badge from the chain, without the fee line. Progress itself never depends on the browser.
- Slice 6: verified on Arc Testnet with throwaway wallets driven through the page's own buttons: join, cancelled prompt, two-step deposit, withdraw, claim, badge image and level, low-funds message with faucet link. The fees the page showed summed to the real balance change exactly ($0.009976).
- Slice 6: the deposit's low-funds check uses 0.02 USDC as "safe" (0.01 deposit plus fee headroom; real fees for the whole journey were about $0.01).
- Slice 7: README written and every command in it checked on a fresh clone (31 tests pass; local anvil deploy and the whole journey script pass). Read-only mainnet check: chain id 5042, official USDC is live (6 decimals), gas price 20 gwei, so a full deployment should cost roughly $0.10-0.15 (README says about $0.50 is plenty).
- Slice 7: a LICENSE file (MIT, "Open Quest contributors") was added so the README's licence line is true; the user can change the copyright holder.
- Slice 7: explorer verification of WithdrawQuest and HolderQuest on testnet is still pending because of the explorer's rate limit; the README states this and gives a manual fallback.
- Mainnet deployment (2026-10-05): deployed by the owner from 0xC2Ab9130E99410e42701936F6d16E012B9a909d5 (block 24390112). Total cost 0.0739 USDC. Read-only checks passed: all six contracts have code, the registry lists 4 quests (3 built-in plus the Holder quest as id 3), badge and registry point at each other, DepositQuest uses the official USDC, WithdrawQuest points at DepositQuest. Addresses are in `deployments/5042.json`, `docs/config.js` (default network is now mainnet) and the README. The owner still needs to complete the journey once on mainnet with their MetaMask wallet.
- Mainnet deployment: a dry run first caught that `.env` held the old testnet key (a stale shell variable plus a key pasted into `.env.example`); fixed by the owner before broadcasting. The key never entered git.
- Final review: the owner completed the whole journey on Arc mainnet with their MetaMask wallet (0x28b8...27B9) and reported that everything worked. Confirmed on-chain: all three quests done, the deposit returned (nothing held for that wallet), one Level 3 badge minted to that wallet.

## Review

Pre-ship review (security, accessibility, performance), 2026-10-05. Checked with tools: git history scans, Foundry tests including new hostile-quest and stateful invariant tests, a mainnet-fork rehearsal, the axe accessibility checker in light and dark mode, browser timing, and manual keyboard tests.

### Findings and what was done

**Must fix**
- Registry: `isComplete()` reverted when a third-party quest returned empty, short or invalid data, although the code comment and README promised it would return false. Only reads were affected (never funds or badge claims). **Fixed** with a low-level `staticcall` that copies at most 32 bytes and accepts only exactly `true`; four new hostile-quest tests (they failed before the fix). The registry was **redeployed** (the three quests are reused, so progress carries over); see the mainnet entries below.

**Should fix (all fixed)**
- Personal email in git commit metadata: history to be rewritten to the GitHub noreply address before the first push.
- Untracked tool folders and `broadcast/` could be swept in by `git add .`: now in `.gitignore`.
- Code example not keyboard-reachable (axe: serious): now focusable, labelled region.
- Keyboard focus lost after every re-render: focus is now restored (next logical button, badge card at the end); buttons stay focusable while working (aria-disabled).
- Page trusted saved fee data and did not re-check the network before sending: saved data is validated, and the network is re-checked right before any transaction (a wallet that moved networks gets the switch banner and nothing is sent).

**Nice to have (done)**
- Text sizes now in rem so they follow the browser's text-size setting.
- Stateful invariant tests added (vault holds exactly the live deposits, per-wallet balance is zero or one deposit, withdrawn implies deposited, badges only for finished wallets at most one each). Mutation check: breaking the withdrawal makes them fail.

### Additions after the review (agreed with the owner)
- Community quests list, register-a-quest form, total-fees line, favicon and social preview image (page only, no contract change).
- Builder kit: `QuestTemplate`, `RegisterQuest` script, `BUILDERS.md`, tests.
- New on-chain badge artwork (needs a new badge contract, so one more registry and badge redeploy at the end).
- `SECURITY.md` and a Slither run (no high or medium findings; 3 notes, all intended).

- Final polish: progress arc hero, quests as a connected path, custom line icons (no emoji), clearer microcopy. Verified with the full journey on a local chain, axe (0 violations, light and dark), keyboard focus, phone width, and mainnet screenshots.

### Knowingly accepted
- The ethers library is about 136 KB over the network versus 33 KB for all project code; removing it needs a build step, which was ruled out.
- GitHub Pages cannot send a `frame-ancestors` header, so clickjacking cannot be blocked by policy; every transaction still needs an explicit wallet confirmation.
- The testnet deployment still uses the first (pre-fix) registry; it is for rehearsal only.

### Not performed
- No static analyzer (Slither), no Lighthouse, no screen-reader test, no real-phone test, no independent audit. OpenZeppelin's advisory page lists no advisory for the parts used, but it does not state affected version ranges, so 5.4.0 could not be proven clean.

### Results
- Tests: 36 passing (9 suites), including 128,000 random actions per invariant run.
- axe: 0 violations in light and dark mode across all page states.
- Mainnet-fork rehearsal: the redeployed registry reads the existing quests, the existing wallet's progress is `[true, true, true]`, claiming works once and is then rejected, four kinds of hostile quest all return `false`.

### Mainnet redeploy (done by the owner, 2026-10-05, block 24395004)
- New QuestRegistry `0x96A0Db0B0D9E5CEA1927b0c782b265e084bBde97` and QuestBadge `0x0d79B8DB6bC88f78A503E1f58432a0b37Efd7102`; cost 0.0579 USDC. Read-only checks: 4 quests registered (the existing three plus the Holder quest), badge and registry point at each other, the owner's wallet shows progress [true, true, true] in the new registry. Addresses are in `deployments/5042.json` (with previousRegistry / previousBadge), `docs/config.js` and the README.

### Mainnet redeploy v3 (done by the owner, 2026-10-05, block 24398713)
- New QuestRegistry `0x9Ec3c3c0626488B3E3d7F7F8E66642BdE698bC1f` and QuestBadge `0xd50920c9E4eC6539269b22FA95f2ACd80D3C970b` with the new on-chain artwork; cost 0.0742 USDC. Read-only checks passed (4 quests, same existing quests, owner's progress [true, true, true], no badge yet). v1 and v2 are recorded in the README as superseded.

### Open
- The owner claims a badge from the v3 registry with their MetaMask wallet (one click, quests are already done).
- Optional: upload the source verification bundles (`verification/`, regenerated for the new registry and badge) on the explorer.
- Shipped 2026-10-05: public repo https://github.com/Philshirt18/open-quest and live page https://philshirt18.github.io/open-quest/ . Pre-push audit clean (no keys, no personal data, noreply identity). Live page verified against Arc mainnet: visitor view, finished-wallet view, badge image, registry link, no console errors.
