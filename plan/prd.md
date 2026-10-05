---
doc: prd
status: approved
---

# Open Quest — Product Requirements

## Overview
Open Quest is a single web page where a newcomer to Arc connects a wallet, completes three guided quests, and earns a non-transferable on-chain badge. Its kernel is that the quest registry is open: any builder can add their own quest with a few lines of code. Develops `scope.md > The Unique Kernel`.

## Core Journey
1. The visitor opens the page and sees a short headline ("An open quest registry on Arc"), one sentence explaining it, a note on how much USDC they need in total, and a Connect wallet button.
2. They connect their wallet. If the wallet is not on Arc, a banner offers a one-click switch or add.
3. They see three numbered quest cards in order: Join, Deposit 0.01 USDC, Withdraw. Only the next available card is active.
4. They complete the active quest with one button and confirm in their wallet. When it is done, the card turns to done and shows the network fee in dollars plus a link to the transaction on the Arc explorer.
5. Deposit takes two wallet confirmations (allow, then deposit), shown as two small steps on the same card.
6. After the withdraw, the deposit is back in their wallet.
7. The Claim badge button unlocks. They claim, and the page shows their badge with its level.
8. Below the quests, an "Add your own quest" section shows the short example and a live example quest.

Develops `scope.md > The Core Loop` and `What "Working" Looks Like`.

## Look and Feel
See `plan/design.md`. Summary: light, clean, calm, inspired by the Arc docs (blue accent, Space Grotesk, lots of whitespace), dark mode following the system setting, mobile-first.

## Features and Behavior

### Connect wallet and network
Connect button, wallet address shown once connected, and a banner offering to add or switch to Arc when the wallet is on another network. All network values come from one config file.
- **Criteria:** with a wallet on another network, the banner appears and one tap switches or adds Arc; afterwards the quests load with no reload.
- **States:** no wallet installed shows a friendly message with a link to get one and the Connect button disabled. Wrong network shows the switch banner and the quest buttons disabled. Network not configured shows a clear message instead of a blank page.

### Cost note
Before connecting, the page tells the visitor roughly how much USDC covers everything (0.01 USDC deposit plus small network fees, "about $0.05 in total", exact number confirmed during the build from real fees).
- **Criteria:** the note is visible before the Connect step and uses plain words (network fee), not "gas".

### Quest sequence
The three quests go in order: Join, Deposit, Withdraw. The active quest is highlighted and has the only bright button. Locked quests are greyed out, disabled, and show a short reason ("Join first", "Deposit first"). Done quests show a check mark, the fee in dollars, and the explorer link.
- **Criteria:** a fresh wallet sees quest 1 active and 2 and 3 locked with reasons; after each quest the next one unlocks.
- **States:** reopening the page later reads progress from the chain, so done quests show as done immediately.
- The order is a page rule only. The contracts accept any order; the badge needs all three checks true (noted in the README).

### Quest 1: Join
One button. It registers the wallet as having joined.
- **Criteria:** after one confirmation the card shows done. Pressing Join twice is not possible from the page; if tried directly on the contract, it is rejected.

### Quest 2: Deposit 0.01 USDC
Two steps: allow the deposit, then deposit 0.01 USDC. The card shows both steps and which one is in progress.
- **Criteria:** after both steps the card shows done and the deposit is held by the contract.
- **States:** not enough USDC for the deposit plus the fee shows "You need at least 0.01 USDC plus a small network fee" under the card, with the faucet link on testnet only.

### Quest 3: Withdraw
One button. It returns the full deposit to the depositor. Deposits can always be withdrawn by the depositor, and nobody else can touch them.
- **Criteria:** after confirmation the card shows done and the wallet balance has the 0.01 USDC back (minus network fees).
- **States:** before a deposit the card is locked ("Deposit first"). Withdrawing without a deposit is rejected by the contract.

### Transaction feedback
After each transaction, the card shows the network fee in US dollars and a link to the transaction on the Arc explorer. While waiting for confirmation, a "Waiting for confirmation" state is shown.
- **Criteria:** the explorer link opens the real transaction; the dollar amount matches the fee paid.
- **States:** the user rejects it in the wallet: nothing changes, a short note says "Cancelled, nothing was sent", and the button works again. The transaction fails or is slow: a plain-language error and a retry button.

### Claim badge
Locked until all three quests are done ("Complete all 3 quests"). Once unlocked, one button claims the badge. The badge is non-transferable and can be claimed once per wallet. It carries a level equal to the number of built-in quests completed, which is always 3 (third-party quests do not change the badge).
- **Criteria:** claiming shows the badge with its level; claiming a second time is impossible (the button is gone and the contract rejects it); the badge cannot be sent to another wallet.
- **States:** if already claimed (page reopened), the badge is shown straight away.

### Add your own quest
A section below the quests. It shows a short code example (about 10 lines) of a quest and how to register it, plus a live example quest ("Holder quest": the wallet holds at least 1 USDC) with its own status for the visitor's wallet. The example is registered on the same registry, through the same open route any builder would use. It is not one of the three main cards.
- **Criteria:** the example code is readable on a phone; the Holder quest shows done or todo for the connected wallet and links to its contract on the explorer.
- **States:** not connected shows the section without a status.

### Registry (open registration)
Anyone can register a quest contract (an address that answers "has this wallet completed it?", plus a name and a short description). The registry tracks which quests each wallet has completed and exposes a wallet's progress.
- **Criteria:** a third-party quest registered by a different address appears in the registry and in a wallet's progress, with no change to the other contracts.

### Community quests (added after the first review)
A section below the three quests lists every quest registered by anyone (newest first, ten at a time), with the connected wallet's status on each ("Done" / "Not done"). Quests written by other people never change the badge. Names and descriptions are shown as plain text with control characters removed.
- **Criteria:** a quest registered by another wallet appears in the list without any change to the page or contracts; a broken quest shows "Not done" and does not break the list.

### Register a quest (added after the first review)
A form (contract address, name up to 64 bytes, optional description up to 280 bytes) that sends `registerQuest` from the visitor's wallet. It shows a preview of what the quest answers for the connected wallet and refuses obvious mistakes (not an address, no contract there, already registered) before asking the wallet for anything.
- **Criteria:** a valid registration shows the fee in dollars and an explorer link and the quest appears in the community list.

### Badge artwork (changed after the first review)
The badge is an on-chain SVG: an arc with one ticked node per quest, the level, "built on Arc" and the owner's short address.

## Product Decisions
- **Open registry is the kernel.** It leads the page and the README. The user wants judges to remember it.
- **Fixed quest order on the page, free order in the contracts.** Guides newcomers without extra contract complexity.
- **Badge level is always 3 (the built-in quests).** Third-party quests are registered and show their own status on the page, but never affect the badge or the claim. Chosen for the lowest risk: no loops over third-party code inside a transaction, so a hostile quest cannot break claiming. Counting third-party quests toward the level is a "What's next" idea.
- **Holder quest as the third-party example,** showing how little code a quest needs.
- **Cost note before connecting,** to reassure newcomers and show off the dollar-cost angle.
- **Design:** accepted as proposed in `plan/design.md`.
- **Name:** "Open Quest" (renamed from "Arc Quest" because the Arc brand toolkit does not allow "Arc" in a product name without qualification). Arc appears only as a description ("built on Arc").

## What We're Building Now
Everything above: connect and network handling, the cost note, the three ordered quests, transaction feedback with dollar cost and explorer link, badge claim and display, the "Add your own quest" section with the live Holder quest, and the open registry behavior. Delivered live on Arc mainnet and GitHub Pages, with a README for judges.

## Deferred
- **Sponsor-funded reward pool:** adds funds and risk; does not help the kernel.
- **More quests:** the three plus one example are enough to prove the idea.
- **Leaderboard:** needs indexing or a backend.
- **Cap per wallet / anti-farming:** a real concern; noted in the README's "What's next".
- **Third-party quests counting toward the badge level, and badge upgrades:** need safe handling of untrusted quest code; deferred for risk reasons.

## Assumptions and Open Questions
- **Fee display:** resolved in the spec (native gas USDC uses 18 decimals, the ERC-20 uses 6).
- **Cost note amount:** "about $0.05" is a placeholder until real fees are measured.
- **Testnet availability and faucet:** resolved in the spec (public testnet and faucet exist).
