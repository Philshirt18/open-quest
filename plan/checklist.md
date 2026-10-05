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

- [ ] **4. Testnet rehearsal with real USDC**
  - Becomes usable: the contracts are live on Arc Testnet, and the whole journey works with the real USDC contract.
  - Why now: the biggest unknowns (real USDC behavior, fee numbers, explorer links) come before any frontend depends on them. You prepare a throwaway deployer key and faucet funds; I never see the key.
  - PRD ref: `prd.md > Transaction feedback`, `prd.md > Cost note`
  - Spec ref: `spec.md > Decisions and Open Issues` (real USDC, fee accuracy, explorer verification)
  - Build: put the key in `.env` (you do it), deploy to testnet, run the journey with `cast`, measure real fees, try `forge verify-contract` on the explorer, and record the testnet addresses in `docs/config.js` and the README.
  - Verify (mechanical): the explorer shows the contracts and transactions; measured gas times price gives the dollar fee per action; withdraw returns the 0.01 USDC.
  - Try it yourself: open your deployed registry on the testnet explorer and see the badge.
  - Commit: `feat: testnet deployment and measured fees`

- [ ] **5. The page: connect, network, progress and look**
  - Becomes usable: you open the page, connect, switch to Arc, and see your real quest status and the cost note, in the agreed design.
  - Why now: reading chain state is lower risk than sending transactions, and sets up the page for slice 6.
  - PRD ref: `prd.md > Connect wallet and network`, `Cost note`, `Quest sequence`
  - Spec ref: `spec.md > Frontend: wallet and network`, `Look and Feel`, `Frontend: cost note, badge, add-your-own`
  - Build: `docs/index.html`, `style.css` (design tokens, light and dark), `config.js` (single config with sources), `app.js` (connect, banner, read progress, cards in done, active and locked states).
  - Verify (mechanical): load the page from a local server; no console errors; screenshots at phone and desktop width compared with `design.md`; all states checked with a test wallet provider.
  - Try it yourself: open `http://localhost:8000` with your wallet and see your quests.
  - Commit: `feat: page with wallet connection and quest progress`

- [ ] **6. The page: quests, fees, badge and "Add your own quest"**
  - Becomes usable: you complete the whole journey on the page, see fees in dollars and explorer links, claim and see your badge, and read the add-a-quest section with the live Holder quest.
  - Why now: the full journey, built on top of working reads.
  - PRD ref: `prd.md > Quest 1`, `Quest 2`, `Quest 3`, `Transaction feedback`, `Claim badge`, `Add your own quest`
  - Spec ref: `spec.md > Frontend: quests and feedback`, `Frontend: cost note, badge, add-your-own`
  - Build: transaction buttons including the two-step deposit, waiting, rejected and failed states, fee in dollars, explorer link, claim button and badge view, the "Add your own quest" section.
  - Verify (mechanical): run the journey on testnet through the page; compare the fee shown with the explorer; error states with a rejected transaction; screenshots at phone and desktop; no console errors.
  - Try it yourself: do the whole journey on testnet with your own wallet.
  - Commit: `feat: full quest journey on the page`

- [ ] **7. README and mainnet launch kit**
  - Becomes usable: a judge can understand the project in two minutes, and you have the exact mainnet commands.
  - Why now: all that's left is documentation and the mainnet step you run yourself.
  - PRD ref: `prd.md > Overview`, `prd.md > Add your own quest`
  - Spec ref: `spec.md > Where It Runs, Deploys, and How Someone Tries It`, `spec.md > Failure Modes`
  - Build: README (what it does, live demo placeholder, addresses, how it uses Arc, add-a-quest in about 10 lines, risks and USDC issuer note, what's next), exact mainnet deploy commands. I do not run the mainnet deployment; you do, and then I write the mainnet addresses into `docs/config.js` and the README.
  - Verify (mechanical): all README commands run as written on a fresh clone; links work; tests pass.
  - Try it yourself: read the README as if you were a judge; then run the mainnet commands I give you.
  - Commit: `docs: README and mainnet launch kit`

## Final Review

- [ ] Project started as the spec describes; relevant checks pass
- [ ] User explored the running app and gave feedback
- [ ] Agreed fixes implemented, verified, committed (list each as its own unchecked item)
- [ ] User confirmed the first version is ready to ship

## Revisions

<!-- One bullet per plan change: what changed, and what the build discovered. -->
- Slice 1: `forge install` could not add git submodules because the project folder name ends with a space, so dependencies were installed with `--no-git` and only their Solidity sources are committed (see `.gitignore`).
- Slice 1: the registry constructor takes the three built-in quests with their names and descriptions and registers them as ids 0-2 (the badge is added in slice 2).
- Slice 2: the reentrancy test passes even without `nonReentrant` because `withdraw()` zeroes the balance before sending funds (checks-effects-interactions). Both layers stay in; the test proves the attack fails, not the guard alone.
