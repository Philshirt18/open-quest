# Security

Open Quest moves real money only in one place (`DepositQuest`, 0.01 USDC per wallet) and has no owner, no admin
and no upgrade path. This page says what is guaranteed, how it is checked, and what is not covered.

## Guarantees and how they are checked

| Guarantee | Where it comes from | Checked by |
|---|---|---|
| Only the depositor can ever take their deposit out, at any time | `DepositQuest.withdraw()` sends only to `msg.sender`; no other function moves funds | `DepositQuestTest`, a stranger cannot withdraw; fuzzing (below) |
| The vault holds exactly the live deposits | state is updated before funds move; one deposit per wallet | invariant test, 128,000 random actions per run |
| A reentrancy attack on withdraw fails | `nonReentrant` plus updating the balance before sending | `DepositQuestReentrancyTest` (the attack fails even without the guard, because the balance is already zero) |
| A badge exists only for wallets that finished all three quests, at most one each | `claimBadge()` checks the three fixed quests and the token id is the wallet address | `QuestBadgeTest`, invariant test |
| The badge cannot be transferred | every transfer path reverts in `_update` | `test_transferringTheBadgeReverts` (including approved operators) |
| A third-party quest cannot block or fake a badge claim | claiming never calls third-party quests | `ThirdPartyQuestTest` |
| A third-party quest cannot make a read revert or burn unbounded gas | gas-limited `staticcall`, copies at most 32 bytes, only exact `true` counts | `HostileQuestTest`: reverting, gas-burning, empty, invalid bool, short, and oversized answers |
| The built-in quests can never be changed | fixed in the registry constructor; no setter, no owner | code review; there is no function to call |
| The page cannot be tricked by quest names | names and descriptions are plain text; control characters removed | page tests with a script-looking name |

## Static analysis

Slither 0.11.4 with all 100 detectors, on `src/` only (`slither . --filter-paths "lib|test|script"`):

- **High / medium: none.**
- Low: 2 "external call inside a loop" notes in `builtInProgress` and `claimBadge`. Both loop over the three fixed,
  trusted built-in quests, never over third-party quests.
- Informational: 1 note that `_safeCheck` uses inline assembly. That is deliberate: it is the safe way to read an
  untrusted contract, and it is covered by the hostile-quest tests above.

OpenZeppelin Contracts 5.4.0 is used for ERC-721, `ReentrancyGuard`, `SafeERC20`, `Strings` and `Base64`. Its published
advisories list no issue in these parts, but the advisory page does not state affected version ranges.

## Known limits (please read)

- **No independent audit has been done.** Use small amounts.
- **USDC is issued by Circle.** Circle can block an address at the token level, which would block that wallet's
  withdrawal. Nothing in these contracts can prevent that.
- **Anyone can farm badges with many wallets.** One wallet gets one badge, but wallets are free to create. A cap per
  wallet or a proof of personhood is listed under "What's next".
- **Quest order is a page rule.** The contracts accept the three quests in any order; the badge still needs all three.
- **Community quests are public and permanent.** The registry cannot remove a quest, and anyone can register one, so
  the page shows them as plain text and never counts them toward the badge.
- **The page is static and runs in your browser.** It cannot send a `frame-ancestors` header on GitHub Pages, so it
  could be framed by another site; every transaction still needs your explicit confirmation in your wallet.
- **Do not send USDC straight to `DepositQuest`.** Only deposits made through `deposit()` can be withdrawn; there is
  no admin to rescue stray funds.

## Reporting a problem

Open an issue on the repository, or contact the author through the GitHub profile
[Philshirt18](https://github.com/Philshirt18). Please do not publish a vulnerability that could put other people's funds at risk before it can be addressed.
