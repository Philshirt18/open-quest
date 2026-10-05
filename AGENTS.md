# Open Quest — project rules

An open on-chain quest registry for newcomers to Arc. Contracts in `src/`, tests in `test/`, static page in `docs/`. Plans live in `plan/` (brief, scope, prd, design, spec, checklist).

## Stack
Solidity 0.8.28 + Foundry + OpenZeppelin v5. Page: plain HTML/CSS/JS with ethers v6, no build step, hosted on GitHub Pages from `docs/`.

## Commands
- Foundry on PATH: `export PATH="$PATH:$HOME/.foundry/bin"`
- Test: `forge test -vv`   Build: `forge build`
- Local chain: `anvil`; deploy: `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast`
- Page locally: `python3 -m http.server 8000 --directory docs`

## Rules
- Never hardcode or commit keys; `.env` stays git-ignored. Never ask for or print private keys.
- Never guess Arc network values; they live only in `docs/config.js` with sources.
- Never run a mainnet deployment or any mainnet transaction without the user's explicit yes.
- No admin powers over user funds. No features beyond `plan/prd.md` unless the user asks.
- Keep contracts small, readable and commented. Run the tests after every change.
- The product is called "Open Quest". Say "built on Arc"; never put "Arc" in the product name or alter the Arc logo.
- Update `plan/checklist.md` after every verified slice.
