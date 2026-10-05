// Open Quest: the page logic. No build step; ethers v6 is loaded from a pinned CDN file (see index.html).
// The page reads everything from the chain, so a reopened page always shows the real state.
import { NETWORKS, DEFAULT_NETWORK, ABI, DEPOSIT_AMOUNT } from "./config.js";

const { ethers } = window;

// Which network: ?network=mainnet or ?network=testnet in the address bar, otherwise the default from config.js.
const requested = new URLSearchParams(location.search).get("network");
const net = NETWORKS[requested] ?? NETWORKS[DEFAULT_NETWORK];

const QUESTS = [
  { title: "Join", text: "Say hello on Arc. One tap, one network fee." },
  { title: "Deposit 0.01 USDC", text: "Put 0.01 USDC in. You can take it back at any time." },
  { title: "Withdraw", text: "Take your 0.01 USDC back. It is always yours." },
];

// state: nowallet | disconnected | wrongnetwork | loading | ready | error | noconfig
const S = {
  state: "disconnected",
  account: null,
  progress: [false, false, false],
  hasBadge: false,
  badge: null, // { level, image } once claimed
  holder: null, // true / false once known: status of the example third-party quest
  readProvider: null,
  // Per card (0 join, 1 deposit, 2 withdraw, 3 claim): what the user is waiting on right now.
  ui: [0, 1, 2, 3].map(() => ({ busy: false, step: 0, msg: "", err: false, faucet: false })),
  txs: { 0: [], 1: [], 2: [], 3: [] }, // fee and explorer link per transaction, remembered in this browser
};

const $ = (id) => document.getElementById(id);
const el = (tag, attrs = {}, ...children) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v);
  }
  for (const c of children) node.append(c);
  return node;
};
const short = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;

function setStatus(text) {
  $("status-line").textContent = text ?? "";
}

// ---- small helpers --------------------------------------------------------------------------

const storeKey = () => `openquest:${net.chainId}:${S.account?.toLowerCase()}`;
function loadTxs() {
  S.txs = { 0: [], 1: [], 2: [], 3: [] };
  try {
    const saved = JSON.parse(localStorage.getItem(storeKey()) ?? "null");
    if (saved) for (const k of [0, 1, 2, 3]) S.txs[k] = Array.isArray(saved[k]) ? saved[k] : [];
  } catch { /* storage can be blocked; the page works without it */ }
}
function saveTxs() {
  try { localStorage.setItem(storeKey(), JSON.stringify(S.txs)); } catch { /* ignore */ }
}

// Fee in US dollars. Native gas USDC has 18 decimals (the ERC-20 interface has 6), so divide by 10^18.
function feeUsd(feeWei) {
  const usd = Number(ethers.formatUnits(BigInt(feeWei), 18));
  return usd < 0.0001 ? "less than $0.0001" : `$${usd.toFixed(4)}`;
}
const txUrl = (hash) => `${net.explorerUrl}/tx/${hash}`;
const addrUrl = (a) => `${net.explorerUrl}/address/${a}`;

function isRejected(e) {
  return e?.code === 4001 || e?.code === "ACTION_REJECTED" || e?.info?.error?.code === 4001;
}

// ---- wallet and network -------------------------------------------------------------------

async function connect() {
  if (!window.ethereum) {
    S.state = "nowallet";
    return render();
  }
  listenToWallet();
  try {
    setStatus("Check your wallet to connect.");
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    S.account = ethers.getAddress(accounts[0]);
    setStatus("");
    await refresh();
  } catch (e) {
    setStatus(e?.code === 4001 ? "Cancelled, nothing was sent." : "Could not connect to your wallet. Try again.");
  }
}

async function switchNetwork() {
  const params = { chainId: net.chainIdHex };
  try {
    await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [params] });
  } catch (e) {
    const unknownChain = e?.code === 4902 || e?.data?.originalError?.code === 4902;
    if (unknownChain) {
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [{
            chainId: net.chainIdHex,
            chainName: net.name,
            nativeCurrency: net.nativeCurrency,
            rpcUrls: [net.rpcUrl],
            blockExplorerUrls: [net.explorerUrl],
          }],
        });
      } catch (e2) {
        setStatus(e2?.code === 4001 ? "Cancelled, nothing was sent." : `Could not add ${net.name}. Try again.`);
      }
    } else {
      setStatus(e?.code === 4001 ? "Cancelled, nothing was sent." : `Could not switch to ${net.name}. Try again.`);
    }
  }
}

async function refresh() {
  if (!net.contracts) {
    S.state = "noconfig";
    return render();
  }
  if (!S.account) {
    S.state = "disconnected";
    return render();
  }
  const chainId = Number(await window.ethereum.request({ method: "eth_chainId" }));
  if (chainId !== net.chainId) {
    S.state = "wrongnetwork";
    return render();
  }
  loadTxs();
  S.state = "loading";
  render();
  await loadProgress();
}

// Read-only calls go through Arc's public RPC, so no wallet permission is needed for reading.
async function loadProgress() {
  try {
    S.readProvider ??= new ethers.JsonRpcProvider(net.rpcUrl, net.chainId, { staticNetwork: true });
    const c = net.contracts;
    const registry = new ethers.Contract(c.questRegistry, ABI.registry, S.readProvider);
    const badge = new ethers.Contract(c.questBadge, ABI.badge, S.readProvider);
    const [progress, hasBadge, holder] = await Promise.all([
      registry.builtInProgress(S.account),
      badge.hasBadge(S.account),
      registry.isComplete(c.holderQuestId, S.account),
    ]);
    S.progress = Array.from(progress, Boolean);
    S.hasBadge = hasBadge;
    S.holder = holder;
    S.badge = hasBadge ? await loadBadge(badge) : null;
    S.state = "ready";
  } catch (e) {
    console.error(e);
    S.state = "error";
  }
  render();
}

// Reads the badge's on-chain metadata (a data: URI), so nothing is hosted anywhere.
async function loadBadge(badge) {
  try {
    const id = await badge.tokenIdOf(S.account);
    const [level, uri] = await Promise.all([badge.levelOf(id), badge.tokenURI(id)]);
    const prefix = "data:application/json;base64,";
    const json = uri.startsWith(prefix) ? JSON.parse(atob(uri.slice(prefix.length))) : {};
    const image = typeof json.image === "string" && json.image.startsWith("data:image/svg+xml;base64,") ? json.image : null;
    return { level: Number(level), image };
  } catch (e) {
    console.error(e);
    return { level: 3, image: null };
  }
}

// ---- actions (each sends one or two transactions from the visitor's own wallet) ----------------------

function friendlyError(e) {
  if (isRejected(e)) return { text: "Cancelled, nothing was sent.", err: false };
  const why = (e?.shortMessage || e?.reason || "").toString().slice(0, 120);
  return { text: `That did not go through${why ? ` (${why})` : ""}. You can try again.`, err: true };
}

// Runs one card's action: shows waiting states, handles cancel and failure, then reloads real progress.
async function act(i, work) {
  const ui = S.ui[i];
  ui.busy = true; ui.msg = ""; ui.err = false; ui.faucet = false; ui.step = 0;
  render();
  try {
    if (await work(ui)) {
      ui.msg = "";
      await loadProgress();
    }
  } catch (e) {
    if (!isRejected(e)) console.error(e); // a user cancelling is normal, not an error
    const f = friendlyError(e);
    ui.msg = f.text; ui.err = f.err;
  } finally {
    ui.busy = false;
    render();
  }
}

// Sends one transaction, waits for it, records its fee and explorer link.
async function runTx(i, label, send) {
  const ui = S.ui[i];
  ui.msg = "Confirm in your wallet…"; render();
  const tx = await send();
  ui.msg = "Waiting for confirmation…"; render();
  const slow = setTimeout(() => { ui.msg = "Still waiting. Arc is usually quick, this can take a moment."; render(); }, 20000);
  try {
    const receipt = await tx.wait();
    if (receipt.status !== 1) throw new Error("The transaction failed on the network.");
    S.txs[i].push({ label, hash: receipt.hash, fee: (receipt.gasUsed * receipt.gasPrice).toString() });
    saveTxs();
  } finally {
    clearTimeout(slow);
  }
}

async function signerContracts() {
  const signer = await new ethers.BrowserProvider(window.ethereum).getSigner();
  const c = net.contracts;
  return {
    registry: new ethers.Contract(c.questRegistry, ABI.registry, signer),
    register: new ethers.Contract(c.registerQuest, ABI.register, signer),
    deposit: new ethers.Contract(c.depositQuest, ABI.deposit, signer),
    usdc: new ethers.Contract(c.usdc, ABI.usdc, signer),
  };
}

const doJoin = () => act(0, async () => {
  const { register } = await signerContracts();
  await runTx(0, "Join", () => register.join());
  return true;
});

const doDeposit = () => act(1, async (ui) => {
  const c = net.contracts;
  const { usdc, deposit } = await signerContracts();
  // Check there is enough USDC before asking the wallet for anything. The native balance (18 decimals)
  // and the USDC token balance (6 decimals) are the same money; we need the deposit plus fee headroom.
  const have = await S.readProvider.getBalance(S.account);
  if (have < 20_000_000_000_000_000n) { // 0.02 USDC in 18-decimal units
    ui.msg = "You need at least 0.01 USDC for the deposit plus a small network fee. About 0.02 USDC in total is safe.";
    ui.faucet = true;
    return false;
  }
  const allowance = await usdc.allowance(S.account, c.depositQuest);
  if (allowance < DEPOSIT_AMOUNT) {
    ui.step = 1;
    await runTx(1, "Allow 0.01 USDC", () => usdc.approve(c.depositQuest, DEPOSIT_AMOUNT)); // exactly 0.01, never unlimited
  }
  ui.step = 2;
  await runTx(1, "Deposit", () => deposit.deposit());
  return true;
});

const doWithdraw = () => act(2, async () => {
  const { deposit } = await signerContracts();
  await runTx(2, "Withdraw", () => deposit.withdraw());
  return true;
});

const doClaim = () => act(3, async () => {
  const { registry } = await signerContracts();
  await runTx(3, "Claim badge", () => registry.claimBadge());
  return true;
});

const ACTIONS = [
  { label: "Join", run: doJoin },
  { label: "Deposit 0.01 USDC", run: doDeposit },
  { label: "Withdraw 0.01 USDC", run: doWithdraw },
];

// ---- rendering ------------------------------------------------------------------------------

function lockedReason(i) {
  switch (S.state) {
    case "ready":
      return i === 1 ? "Join first" : "Deposit first";
    case "wrongnetwork":
      return `Switch to ${net.name} first`;
    case "loading":
      return "Loading your progress…";
    case "error":
    case "noconfig":
      return "Not available right now";
    default:
      return "Connect your wallet first";
  }
}

function questState(i) {
  if (S.state === "ready") {
    if (S.progress[i]) return "done";
    const firstTodo = S.progress.findIndex((d) => !d);
    return i === firstTodo ? "active" : "locked";
  }
  return "locked";
}

function renderBanner() {
  const banner = $("banner");
  const btn = $("banner-btn");
  const text = $("banner-text");
  banner.classList.remove("error");
  btn.hidden = true;
  btn.onclick = null;
  let show = true;
  switch (S.state) {
    case "nowallet":
      text.replaceChildren(
        "You need a wallet to start. A wallet is an app that holds your USDC and signs your actions. ",
        el("a", { href: "https://ethereum.org/en/wallets/find-wallet/", target: "_blank", rel: "noopener noreferrer" }, "Find a wallet"),
        ", then come back and reload this page.",
      );
      break;
    case "wrongnetwork":
      text.textContent = `Your wallet is on a different network. Switch to ${net.name} to continue.`;
      btn.textContent = `Switch to ${net.name}`;
      btn.hidden = false;
      btn.onclick = switchNetwork;
      break;
    case "error":
      banner.classList.add("error");
      text.textContent = "Can't reach Arc right now. Check your connection and try again.";
      btn.textContent = "Try again";
      btn.hidden = false;
      btn.onclick = () => { S.state = "loading"; render(); loadProgress(); };
      break;
    case "noconfig":
      banner.classList.add("error");
      text.textContent = `Open Quest is not set up for ${net.name} yet. Contract addresses are missing.`;
      break;
    default:
      show = false;
  }
  banner.hidden = !show;
}

function renderToolbar() {
  const connected = Boolean(S.account);
  $("connect-btn").hidden = connected;
  $("connect-btn").disabled = S.state === "nowallet";
  $("account-pill").hidden = !connected;
  if (connected) $("account-text").textContent = short(S.account);
  $("network-text").textContent = net.name;
  $("network-pill").querySelector(".dot").classList.toggle("ok", S.state === "ready");
}

// One line per transaction: what it was, what it cost in dollars, and a link to it on the explorer.
function feeLines(i) {
  return S.txs[i].map((t) =>
    el("p", { class: "feedback" },
      `${t.label}: network fee ${feeUsd(t.fee)} · `,
      el("a", { href: txUrl(t.hash), target: "_blank", rel: "noopener noreferrer" }, "View transaction")),
  );
}

function feedback(i) {
  const ui = S.ui[i];
  if (!ui.msg) return [];
  const node = el("p", { class: `feedback${ui.err ? " error" : ""}`, role: ui.err ? "alert" : "status" }, ui.msg);
  if (ui.faucet && net.faucetUrl) {
    node.append(" ", el("a", { href: net.faucetUrl, target: "_blank", rel: "noopener noreferrer" }, "Get test USDC"), ".");
  }
  return [node];
}

function depositSteps() {
  const ui = S.ui[1];
  return el("ol", { class: "steps", "aria-label": "Deposit steps" },
    el("li", { class: ui.busy && ui.step === 1 ? "current" : "" }, "1. Allow 0.01 USDC"),
    el("li", { class: ui.busy && ui.step === 2 ? "current" : "" }, "2. Deposit"));
}

function renderQuests() {
  const list = $("quests");
  list.replaceChildren(
    ...QUESTS.map((q, i) => {
      const st = questState(i);
      const ui = S.ui[i];
      const stateLine =
        st === "done"
          ? el("p", { class: "state" }, el("span", { class: "check", "aria-hidden": "true" }, "✓"), "Done")
          : st === "active"
            ? el("p", { class: "state" }, "Your next step")
            : el("p", { class: "state" }, el("span", { "aria-hidden": "true" }, "🔒"), lockedReason(i));
      const actions = el("div", { class: "actions", id: `actions-${i}` });
      if (st === "active") {
        actions.append(el("button", { class: "btn primary", type: "button", onclick: ACTIONS[i].run, ...(ui.busy ? { disabled: "" } : {}) },
          ui.busy ? "Working…" : ACTIONS[i].label));
      }
      const body = el("div", {}, el("h3", {}, q.title), el("p", { class: "muted" }, q.text), stateLine, actions);
      if (i === 1 && st === "active") body.append(depositSteps());
      body.append(...feedback(i), ...(st === "done" || st === "active" ? feeLines(i) : []));
      return el("li", { class: `quest ${st}`, "data-quest": String(i) }, el("div", { class: "num", "aria-hidden": "true" }, String(i + 1)), body);
    }),
  );
}

// The badge card: locked until all three quests are done, then claimable, then shown.
function renderBadge() {
  const area = $("badge-area");
  const ui = S.ui[3];
  const allDone = S.state === "ready" && S.progress.every(Boolean);
  if (S.state === "ready" && S.hasBadge) {
    const level = S.badge?.level ?? 3;
    const card = el("section", { class: "badge-card", "aria-label": "Your badge" },
      S.badge?.image ? el("img", { src: S.badge.image, alt: `Open Quest badge, level ${level}` }) : "",
      el("h3", {}, `Level ${level} badge`),
      el("p", { class: "muted" }, "It's yours for good. This badge can't be sent to anyone else."),
      ...feeLines(3));
    area.replaceChildren(card);
    return;
  }
  const actions = el("div", { class: "actions" });
  actions.append(el("button", { class: "btn primary", type: "button", onclick: doClaim, ...(allDone && !ui.busy ? {} : { disabled: "" }) },
    ui.busy ? "Working…" : "Claim badge"));
  const reason = allDone ? "All three quests are done." : S.state === "ready" ? "Complete all 3 quests" : "Connect your wallet first";
  area.replaceChildren(
    el("section", { class: `quest ${allDone ? "active" : "locked"}`, "aria-label": "Claim your badge" },
      el("div", { class: "num", "aria-hidden": "true" }, "★"),
      el("div", {}, el("h3", {}, "Your badge"),
        el("p", { class: "muted" }, "A soulbound badge: it stays in your wallet and can't be transferred."),
        el("p", { class: "state" }, el("span", { "aria-hidden": "true" }, allDone ? "" : "🔒"), reason),
        actions, ...feedback(3), ...feeLines(3))));
}

// The live example for builders: does this wallet pass the example third-party quest?
function renderHolder() {
  const c = net.contracts;
  const status = $("holder-status");
  const links = $("builder-links");
  if (!c) { status.textContent = ""; links.replaceChildren(); return; }
  links.replaceChildren(
    el("a", { href: addrUrl(c.questRegistry), target: "_blank", rel: "noopener noreferrer" }, "QuestRegistry"),
    " · ",
    el("a", { href: addrUrl(c.holderQuest), target: "_blank", rel: "noopener noreferrer" }, "Example Holder quest"));
  status.textContent =
    S.state !== "ready" ? "Connect your wallet to see your status on the example quest."
      : S.holder ? "Example quest status for your wallet: done. You hold at least 1 USDC."
        : "Example quest status for your wallet: not done yet. Hold at least 1 USDC to complete it.";
}

function render() {
  renderToolbar();
  renderBanner();
  renderQuests();
  renderBadge();
  renderHolder();
}

// ---- start ----------------------------------------------------------------------------------

let listening = false;
// Listen for wallet changes. Called at load and again on connect, because some wallets inject late.
function listenToWallet() {
  if (listening || !window.ethereum) return;
  listening = true;
  window.ethereum.on?.("accountsChanged", (accounts) => {
    S.account = accounts[0] ? ethers.getAddress(accounts[0]) : null;
    refresh();
  });
  window.ethereum.on?.("chainChanged", () => refresh());
}

function start() {
  $("connect-btn").addEventListener("click", connect);
  if (window.ethereum) {
    listenToWallet();
    // Reconnect quietly if this site was already allowed (no wallet pop-up).
    window.ethereum
      .request({ method: "eth_accounts" })
      .then((accounts) => {
        if (accounts[0]) {
          S.account = ethers.getAddress(accounts[0]);
          return refresh();
        }
      })
      .catch(() => {});
  }
  render();
}

if (!ethers) {
  $("banner-text").textContent = "The page could not load its wallet library. Check your connection and reload.";
  $("banner").hidden = false;
  $("banner").classList.add("error");
} else {
  start();
}
