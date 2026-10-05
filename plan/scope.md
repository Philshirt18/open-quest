---
doc: scope
status: approved
---

# Open Quest

An open quest registry on Arc: a newcomer completes three quests and earns a soulbound badge, and any builder can add their own quest.

## The Unique Kernel
**The registry is open.** A quest is just a contract with `check(address user) -> bool`, so any builder can plug in their own quest in about 10 lines without asking anyone. The three built-in quests are the example of how it works. This is what the judges should remember.

## Who It's For
A newcomer to Arc who has a wallet (or is getting one) and wants a guided first run through what makes Arc different: USDC as gas and as the deposit token. Second audience: a builder who wants to give newcomers their own quest. Today newcomers follow scattered guides, and quest platforms like Galxe, Zealy and Layer3 run mostly off-chain on one company's backend.

## The Core Loop
Connect wallet, do a quest (Join, Deposit 0.01 USDC, Withdraw), see it turn to done with its dollar cost and explorer link, then claim the badge once all three are done. For a builder: write a quest contract, register it.

## Inspiration & Identity
- Look: inspired by the official Arc docs ([docs.arc.io](https://docs.arc.io/)), not a copy. Light, clean, lots of whitespace, blue accent (about #4d8ee9 / #5FBFFF), Space Grotesk font with light headings, dark mode following the system setting, big simple quest cards. Mobile-friendly.
- Tone: friendly and plain for newcomers, no jargon (for example "network fee ($0.003)").
- Branding: "Built on Arc" wording to be checked against the [Arc Brand Guidelines & Partner Toolkit](https://arc.io/brand-guidelines-and-partner-toolkit); the name was changed from "Arc Quest" to "Open Quest" because the toolkit does not allow "Arc" in a product name without qualification. Arc appears only as a description ("built on Arc").

## Research
- [Galxe / Zealy / Layer3](https://thegrid.id/discovery/productType/questing-platform): big quest platforms with points, tokens and campaigns. Strong on reach; verification is mostly off-chain through social APIs, and quests are created through the company's platform, not by anyone.
- [Arc House](https://community.arc.io/): official Arc community dashboard for points and onboarding actions. A points system run by one company, not open contracts.
- [ARC-Quests](https://github.com/tanka420/ARC-Quests): quest board dApp on Arc testnet with USDC gas and daily engagement tracking. Closest existing idea; testnet-only.
- **What is different here:** all verification is on-chain, quests are open to any builder through a one-function interface, the badge is soulbound, and it targets Arc mainnet with the USDC-as-gas and USDC-deposit experience, including a dollar cost after each transaction.

## Why This Matters to the User
Entry for the Arc Microgrants hackathon (deadline Oct 14, 2026): finish a small thing fully rather than a big thing halfway, live on Arc mainnet, with a strong chance at one of the 20 grants of 500 USDC.

## What "Working" Looks Like
A judge opens the GitHub Pages link on a phone or laptop. They see a clean "Open Quest" page with one sentence saying it is an open quest registry on Arc where anyone can add a quest, and a "Connect wallet" button. After connecting, the page offers to add or switch to Arc mainnet. Three quest cards (Join, Deposit 0.01 USDC, Withdraw) show todo or done. After each transaction a line shows the network fee in dollars and a link to the real transaction on the Arc explorer. After the withdraw, the deposit is back in the wallet. "Claim badge" shows the soulbound badge at Level 3. Below the quests is an "Add your own quest" section with the roughly 10-line example and a link to a third-party example quest contract that is also registered on mainnet (shown on the page in that section and in the README, not as a fourth card). The public GitHub repo has a README that explains everything in two minutes, lists the deployed addresses, and has passing tests.

**Done when:** the contracts are deployed on Arc mainnet by the user, the page is live and pointed at them, the user has completed the whole journey once with real transactions, and the repo is public. Target: deployed by about Oct 11-12, submitted before Oct 14, 23:59 ET.

## The First-Version Boundary
In:
- Contracts: QuestRegistry (open registration, per-wallet progress, badge claim), RegisterQuest, DepositQuest, WithdrawQuest, QuestBadge (soulbound ERC-721 with on-chain level), one third-party example quest.
- Foundry tests for the listed cases, deploy script (key from environment variable), local and testnet rehearsal, then mainnet deployment by the user.
- One static page (plain HTML + ethers.js, no build step) on GitHub Pages: wallet connect, add/switch Arc network, three quest cards, dollar cost and explorer link after each transaction, badge display, "Add your own quest" section.
- One config file for all Arc network values, each sourced from the official docs.
- README: what it does, live demo link, deployed addresses, how it uses Arc, add-a-quest in about 10 lines, "What's next".
- Public repo, with no keys committed.

## Later
- Sponsor-funded reward pool.
- More quests.
- Leaderboard.
- Cap per wallet to prevent farming.

## Explicitly Cut
- Backend, database, accounts or logins: the whole point is that everything is verified on-chain, and there is no time or budget.
- Paid services: a stated constraint.
- Extra built-in quests beyond the three: scope is strict and the deadline is 9 days.
- Reward pool and leaderboard: listed under Later only; they would add risk without helping the kernel.
- Admin powers over user funds: deposits must always be fully withdrawable by the depositor.
