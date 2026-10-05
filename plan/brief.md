---
doc: brief
status: draft
---

# Project Brief

## Idea
"Open Quest" (originally "Arc Quest"; renamed to follow the Arc brand rules): an on-chain onboarding tool for newcomers to the Arc blockchain (Circle's L1, where USDC is the gas token). A newcomer connects a wallet, completes three quests, and receives a non-transferable (soulbound) on-chain badge. All verification is done by smart contracts. No backend, no database, no paid services.

Why: entry for the Arc Microgrants hackathon. Deadline: **Oct 14, 2026**. Scope is strict: finish a small thing fully rather than a big thing halfway. No features beyond the spec (no reward pool, leaderboard, or extra quests) unless the user asks.

Planned parts (from the user's own spec):
- **QuestRegistry:** anyone can register a quest (a contract implementing `IQuest.check(address) -> bool`, plus name/description). Tracks completed quests per wallet. A wallet claims a badge once all built-in quests are true.
- **Built-in quests:** RegisterQuest (`join()`), DepositQuest (deposit 0.01 USDC via approve + transferFrom), WithdrawQuest (withdraw own deposit). Deposits are always fully withdrawable by the depositor; no admin can touch user funds.
- **QuestBadge:** soulbound ERC-721, minted once per wallet, with an on-chain level (number of quests completed).
- **Tests (Foundry):** each quest's happy path, double-join, withdraw before deposit, claim too early, claim twice, soulbound transfer reverts, custom third-party quest.
- **Frontend:** one static page (plain HTML + ethers.js, no build step): connect wallet, switch/add Arc network, three quests with todo/done status and a button each, cost in USD plus explorer link after each transaction, badge shown once earned. Hostable free on GitHub Pages, clean and mobile-friendly.
- **Deployment:** Foundry deploy script reading the private key from an environment variable. Test on anvil, then Arc testnet if available. Mainnet deployment is done by the user only, never by the agent without asking.
- **README (important for judging):** what it does, live demo link placeholder, deployed addresses, how it uses Arc (USDC as gas and deposit token, dollar-cost display), how a third party adds a quest in about 10 lines, and a "What's next" section (sponsor-funded reward pool, more quests, leaderboard, per-wallet cap against farming).

## Kind of Project
Smart contracts (Solidity, Foundry, OpenZeppelin where useful) plus a static website (plain HTML + ethers.js). Runs on the Arc network (testnet first, mainnet by the user). Frontend hosted on GitHub Pages.

## Preferences and Constraints
- Working order, one step at a time, tests run and a summary after each: 1) contracts + tests, 2) deploy script + local deployment, 3) frontend, 4) README.
- Keep contracts small, readable, commented. Guard against reentrancy and double-claiming.
- Never guess Arc network values (RPC URL, chain ID, USDC address, explorer URL). Look them up in the official Arc docs, keep them in a single config file, and tell the user where each value came from. Ask if unclear.
- Never hardcode or commit keys; `.env` is in `.gitignore`.
- Ask before any mainnet action.
- Look and feel (user said "your call"): inspired by the official Arc docs style (docs.arc.io) but not a copy. Light, clean, lots of whitespace, blue accent (about #4d8ee9 / #5FBFFF), Space Grotesk font with light headings, dark mode following the system setting, big simple quest cards, plain newcomer-friendly wording (e.g. "network fee ($0.002)" instead of jargon). Mobile-friendly.
- The user wants suggestions alongside questions they may not be able to answer.

## Notes and Open Questions
- Official Arc site/docs: https://docs.arc.io/ (confirmed by the user). The unrelated arc.ai is NOT Circle's Arc.
- Network details are not yet looked up. Likely sources: https://docs.arc.io/arc/references/connect-to-arc (RPC, chain ID), https://docs.arc.io/arc/references/contract-addresses (USDC), https://faucet.circle.com (testnet tokens). Search results mention mainnet chain ID 5042; unverified, check in the docs.
- Whether a public Arc testnet is available for deployment: to verify in the spec step.
- Microgrants rules (read on https://dorahacks.io/hackathon/arc-microgrants/detail): 20 grants of 500 USDC; submissions close Oct 14, 2026 23:59 ET (decisions by Oct 21). The submission needs: (1) a live deployment on Arc mainnet with a link that opens, (2) a public repo, (3) a short description of what it does and what it uses Arc for, (4) a public builder profile (GitHub, X, or Farcaster). Not eligible: testnet-only, mockups, no Arc component, already Circle/Arc-funded. Judged on: relevance to Arc, technical credibility, quality, and whether it is worth taking further. Pseudonymous submission is allowed. So the mainnet deployment (done by the user, needs a little USDC on Arc for gas) is a hard requirement, not optional. The user's frontend must be live (GitHub Pages) and pointed at mainnet.
- "Built on Arc" wording: Arc has a Brand Guidelines & Partner Toolkit (https://arc.io/brand-guidelines-and-partner-toolkit). Per search results: the Arc logo may only be used by projects actually building on Arc, unmodified and not more prominent than our own branding; do not put "Arc" in the product name or app icon (the name "Open Quest" may conflict, check the toolkit); descriptive phrasing like "Built on Arc" is allowed. Verify in the toolkit before using the logo or naming.
- Demo link placeholder to fill after GitHub Pages is set up.
