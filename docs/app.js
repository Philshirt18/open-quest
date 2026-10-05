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
  readProvider: null,
  // Per card (0 join, 1 deposit, 2 withdraw, 3 claim, 4 register a quest): what the user is waiting on right now.
  ui: [0, 1, 2, 3, 4].map(() => ({ busy: false, step: 0, msg: "", err: false, faucet: false, okMsg: "" })),
  txs: { 0: [], 1: [], 2: [], 3: [], 4: [] }, // fee and explorer link per transaction, remembered in this browser
  community: { items: [], total: 0, shown: 10, status: "idle" }, // quests registered by anyone (ids 3 and up)
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
// Small line icons in the same style as the arc (replace emoji and stock glyphs).
const SVGNS = "http://www.w3.org/2000/svg";
const ICONS = {
  lock: ["M6 11h12v9H6z", "M8.5 11V8a3.5 3.5 0 0 1 7 0v3"],
  check: ["M5 12.5l4.5 4.5L19 7.5"],
  arc: ["M3.5 18a8.5 8.5 0 0 1 17 0", "M3.5 18h.01M12 9.5h.01M20.5 18h.01"],
};
function icon(name, size = 16) {
  const svg = document.createElementNS(SVGNS, "svg");
  for (const [k, v] of Object.entries({ viewBox: "0 0 24 24", width: size, height: size, "aria-hidden": "true", fill: "none",
    stroke: "currentColor", "stroke-width": name === "arc" ? "2.6" : "2.2", "stroke-linecap": "round", "stroke-linejoin": "round", class: "ic" })) svg.setAttribute(k, v);
  for (const d of ICONS[name]) { const p = document.createElementNS(SVGNS, "path"); p.setAttribute("d", d); svg.append(p); }
  return svg;
}
const short = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;
// Names and descriptions of community quests are written by strangers. They are only ever shown as plain
// text, and invisible control and text-direction characters are removed first.
const clean = (s) => String(s).replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g, "").trim();

function setStatus(text) {
  $("status-line").textContent = text ?? "";
}

// ---- small helpers --------------------------------------------------------------------------

const storeKey = () => `openquest:${net.chainId}:${S.account?.toLowerCase()}`;
function loadTxs() {
  S.txs = { 0: [], 1: [], 2: [], 3: [], 4: [] };
  try {
    const saved = JSON.parse(localStorage.getItem(storeKey()) ?? "null");
    // Only keep entries with exactly the expected shape; anything else in storage is ignored.
    const valid = (t) =>
      t && typeof t.label === "string" && t.label.length <= 40 &&
      /^0x[0-9a-fA-F]{64}$/.test(t.hash) && /^[0-9]{1,30}$/.test(String(t.fee));
    if (saved) for (const k of [0, 1, 2, 3, 4]) S.txs[k] = Array.isArray(saved[k]) ? saved[k].filter(valid) : [];
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
    const [progress, hasBadge] = await Promise.all([registry.builtInProgress(S.account), badge.hasBadge(S.account)]);
    S.progress = Array.from(progress, Boolean);
    S.hasBadge = hasBadge;
    S.badge = hasBadge ? await loadBadge(badge) : null;
    S.state = "ready";
  } catch (e) {
    console.error(e);
    S.state = "error";
  }
  render();
  if (S.state === "ready") {
    await loadCommunity();
    previewQuest();
  }
}

// ---- community quests: everything registered by anyone, read straight from the registry ------------

function readRegistry() {
  S.readProvider ??= new ethers.JsonRpcProvider(net.rpcUrl, net.chainId, { staticNetwork: true });
  return new ethers.Contract(net.contracts.questRegistry, ABI.registry, S.readProvider);
}

async function loadCommunity() {
  if (!net.contracts) return;
  try {
    const registry = readRegistry();
    const total = Number(await registry.questCount());
    const FIRST = 3; // ids 0, 1 and 2 are the built-in quests
    const ids = [];
    for (let id = total - 1; id >= FIRST && ids.length < S.community.shown; id--) ids.push(id); // newest first
    const canSee = S.state === "ready" && S.account;
    const items = await Promise.all(ids.map(async (id) => {
      const q = await registry.getQuest(id);
      const done = canSee ? await registry.isComplete(id, S.account) : null; // safe read: a broken quest is just "not done"
      return { id, quest: q.quest, registrant: q.registrant, name: clean(q.name), description: clean(q.description), done };
    }));
    S.community = { ...S.community, items, total: Math.max(0, total - FIRST), status: "ok" };
  } catch (e) {
    console.error(e);
    S.community.status = "error";
  }
  renderCommunity();
}

function renderCommunity() {
  const list = $("community");
  const more = $("community-more");
  const status = $("community-status");
  const c = S.community;
  if (!net.contracts) { list.replaceChildren(); more.hidden = true; status.textContent = ""; return; }
  if (c.status === "error") {
    list.replaceChildren();
    more.hidden = true;
    status.textContent = "Can't load the community quests right now. Reload the page to try again.";
    return;
  }
  if (c.status === "idle") { status.textContent = "Loading community quests…"; return; }
  const seeStatus = S.state === "ready";
  status.textContent =
    c.total === 0 ? "No community quests yet. Yours could be the first." :
    seeStatus ? `${c.total} community ${c.total === 1 ? "quest" : "quests"}. They never change your badge.` :
    `${c.total} community ${c.total === 1 ? "quest" : "quests"}. Connect your wallet to see your status on each.`;
  list.replaceChildren(...c.items.map((q) => {
    const chip = q.done === null ? "" : q.done ? "Done" : "Not done";
    return el("li", { class: "cq" },
      el("div", { class: "cq-head" },
        el("h3", {}, q.name || "(no name)"),
        chip ? el("span", { class: `chip ${q.done ? "yes" : "no"}` }, q.done ? icon("check", 14) : "", chip) : ""),
      q.description ? el("p", { class: "muted" }, q.description) : "",
      el("p", { class: "small muted" },
        `Quest #${q.id} · by `,
        el("a", { href: addrUrl(q.registrant), target: "_blank", rel: "noopener noreferrer", class: "mono" }, short(q.registrant)),
        " · ",
        el("a", { href: addrUrl(q.quest), target: "_blank", rel: "noopener noreferrer" }, "view contract")));
  }));
  more.hidden = c.total <= c.items.length;
}

// ---- register a quest (a form that sends the same transaction anyone can send) -------------------

const utf8Length = (s) => new TextEncoder().encode(s).length;

function readForm() {
  return { address: $("reg-address").value.trim(), name: $("reg-name").value.trim(), desc: $("reg-desc").value.trim() };
}

function validateForm(f) {
  if (!ethers.isAddress(f.address)) return "Enter the address of your quest contract (0x… with 42 characters).";
  if (!f.name) return "Give your quest a name.";
  if (utf8Length(f.name) > 64) return "The name can be at most 64 bytes.";
  if (utf8Length(f.desc) > 280) return "The description can be at most 280 bytes.";
  return "";
}

// Before registering, ask the contract the one question a quest must answer, for the connected wallet.
async function previewQuest() {
  const out = $("reg-preview");
  out.textContent = "";
  const addr = $("reg-address").value.trim();
  if (!ethers.isAddress(addr) || S.state !== "ready") return;
  try {
    const code = await S.readProvider.getCode(addr);
    if (code === "0x") { out.textContent = `There is no contract at this address on ${net.name}.`; return; }
    if (await readRegistry().isRegistered(addr)) { out.textContent = "This contract is already registered."; return; }
    const iface = new ethers.Interface(["function check(address) view returns (bool)"]);
    try {
      const raw = await S.readProvider.call({ to: addr, data: iface.encodeFunctionData("check", [S.account]), gasLimit: 100000 });
      const word = raw.length === 66 ? BigInt(raw) : null;
      out.textContent =
        word === 1n ? "Preview: your quest says this wallet is done." :
        word === 0n ? "Preview: your quest says this wallet is not done yet." :
        "Preview: this contract answered, but not with a clean true or false. It would always show as not done.";
    } catch {
      out.textContent = "Preview: this contract did not answer check(address). You can still register it, but it would always show as not done.";
    }
  } catch { /* the preview is a convenience; the real checks run again when you register */ }
}

function doRegister() {
  if (S.state !== "ready") {
    S.ui[4].msg = S.state === "wrongnetwork" ? `Switch to ${net.name} first.` : "Connect your wallet first.";
    S.ui[4].err = true;
    return renderRegister();
  }
  return registerQuest();
}

const registerQuest = () => act(4, async (ui) => {
  const f = readForm();
  const problem = validateForm(f);
  if (problem) { ui.msg = problem; ui.err = true; return false; }
  if ((await S.readProvider.getCode(f.address)) === "0x") { ui.msg = `There is no contract at that address on ${net.name}.`; ui.err = true; return false; }
  const { registry } = await signerContracts();
  if (await registry.isRegistered(f.address)) { ui.msg = "That contract is already registered."; ui.err = true; return false; }
  await runTx(4, "Register quest", () => registry.registerQuest(f.address, f.name, f.desc));
  $("reg-address").value = ""; $("reg-name").value = ""; $("reg-desc").value = ""; $("reg-preview").textContent = "";
  S.community.shown = Math.max(S.community.shown, 10);
  ui.okMsg = "Registered. It's now in the community list above.";
  return true;
});

function renderRegister() {
  const ui = S.ui[4];
  const btn = $("reg-submit");
  const hint = $("reg-hint");
  btn.setAttribute("aria-disabled", String(ui.busy || S.state !== "ready"));
  btn.textContent = ui.busy ? "Working…" : "Register quest";
  hint.textContent = S.state === "ready" ? "" : S.state === "wrongnetwork" ? `Switch to ${net.name} to register.` : "Connect your wallet to register a quest.";
  const fb = $("reg-feedback");
  const nodes = [];
  if (ui.msg) nodes.push(el("p", { class: `feedback${ui.err ? " error" : ""}`, role: ui.err ? "alert" : "status" }, ui.msg));
  nodes.push(...feeLines(4));
  fb.replaceChildren(...nodes);
}

// The arc at the top: the same arc as the badge, filling up as quests are completed.
function renderHero() {
  const ready = S.state === "ready";
  const done = ready ? S.progress.filter(Boolean).length : 0;
  const next = ready ? S.progress.findIndex((d) => !d) : -1;
  const earned = ready && S.hasBadge;
  const LENGTH = 471.24; // length of the arc path
  const frac = done >= 3 ? 1 : done === 2 ? 0.5 : 0; // the arc reaches the last finished stop
  $("arc-fill").setAttribute("stroke-dashoffset", String(LENGTH * (1 - frac)));
  document.querySelectorAll("#arc .stop").forEach((g, i) => {
    const on = ready && S.progress[i];
    g.classList.toggle("on", Boolean(on));
    g.classList.toggle("next", ready && i === next);
  });
  $("hero").classList.toggle("earned", earned);
  const count = earned ? `${S.badge?.level ?? 3}` : String(done);
  $("arc-count").replaceChildren(count, earned ? "" : el("span", {}, "/3"));
  $("arc-label").textContent = earned ? "level" : "quests done";
  let note;
  if (earned) note = "Badge earned. It's yours for good.";
  else if (ready && done === 3) note = "All three done. Claim your badge below.";
  else if (ready) note = `Next up: ${QUESTS[next].title}.`;
  else note = {
    nowallet: "You need a wallet to start.",
    wrongnetwork: `Switch to ${net.name} to see your progress.`,
    loading: "Reading the chain…",
    error: "Can't reach Arc right now.",
    noconfig: "Not set up on this network yet.",
  }[S.state] ?? "Connect your wallet to begin.";
  $("arc-note").textContent = note;
  $("arc").setAttribute("aria-label", earned ? `Level ${S.badge?.level ?? 3} badge earned` : `Progress: ${done} of 3 quests done`);
}

function renderFees() {
  const all = Object.values(S.txs).flat();
  const box = $("fees-summary");
  if (!all.length || S.state !== "ready") { box.hidden = true; return; }
  const total = all.reduce((sum, t) => sum + BigInt(t.fee), 0n);
  box.textContent = `Network fees paid so far in this browser: ${feeUsd(total)} across ${all.length} ${all.length === 1 ? "transaction" : "transactions"}. Fees on Arc are paid in USDC, so this is the whole cost. Your 0.01 USDC deposit comes back to you.`;
  box.hidden = false;
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

// The wallet could have been switched to another network after the page loaded. Check again right
// before sending anything; if it moved, show the "switch network" banner instead of sending.
async function onRightNetwork() {
  const chainId = Number(await window.ethereum.request({ method: "eth_chainId" }));
  if (chainId === net.chainId) return true;
  await refresh();
  return false;
}

// Runs one card's action: shows waiting states, handles cancel and failure, then reloads real progress.
async function act(i, work) {
  const ui = S.ui[i];
  if (ui.busy) return; // buttons stay focusable while working, so ignore a second press
  ui.busy = true; ui.msg = ""; ui.okMsg = ""; ui.err = false; ui.faucet = false; ui.step = 0;
  render();
  try {
    if (!(await onRightNetwork())) return;
    if (await work(ui)) {
      ui.msg = ui.okMsg || "";
      ui.okMsg = "";
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
          ? el("p", { class: "state" }, el("span", { class: "check" }, icon("check")), "Done")
          : st === "active"
            ? el("p", { class: "state" }, "Next up")
            : el("p", { class: "state" }, icon("lock"), lockedReason(i));
      const actions = el("div", { class: "actions", id: `actions-${i}` });
      if (st === "active") {
        actions.append(el("button", { class: "btn primary", type: "button", "data-focus-key": `action-${i}`, onclick: ACTIONS[i].run, ...(ui.busy ? { "aria-disabled": "true" } : {}) },
          ui.busy ? "Working…" : ACTIONS[i].label));
      }
      const body = el("div", { class: "body" }, el("h3", {}, q.title), el("p", { class: "muted" }, q.text), stateLine, actions);
      if (i === 1 && st === "active") body.append(depositSteps());
      body.append(...feedback(i), ...(st === "done" || st === "active" ? feeLines(i) : []));
      return el("li", { class: `quest ${st}`, "data-quest": String(i) },
        el("div", { class: "num", "aria-hidden": "true" }, st === "done" ? icon("check", 22) : String(i + 1)), body);
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
    const card = el("section", { class: "badge-card", "aria-label": "Your badge", tabindex: "-1", "data-focus-key": "badge" },
      S.badge?.image ? el("img", { src: S.badge.image, alt: `Open Quest badge, level ${level}` }) : "",
      el("h3", {}, `Level ${level} badge`),
      el("p", { class: "muted" }, "It's yours for good. This badge can't be sent to anyone else."),
      ...feeLines(3));
    area.replaceChildren(card);
    return;
  }
  const actions = el("div", { class: "actions" });
  actions.append(el("button", { class: "btn primary", type: "button", "data-focus-key": "claim", onclick: doClaim,
    ...(!allDone ? { disabled: "" } : ui.busy ? { "aria-disabled": "true" } : {}) },
    ui.busy ? "Working…" : "Claim badge"));
  const reason = allDone ? "All three quests are done." : S.state === "ready" ? "Complete all 3 quests" : "Connect your wallet first";
  area.replaceChildren(
    el("section", { class: `quest ${allDone ? "active" : "locked"}`, "aria-label": "Claim your badge" },
      el("div", { class: "num", "aria-hidden": "true" }, icon("arc", 24)),
      el("div", { class: "body" }, el("h3", {}, "Your badge"),
        el("p", { class: "muted" }, "A soulbound badge: it stays in your wallet and can't be transferred."),
        el("p", { class: "state" }, allDone ? "" : icon("lock"), reason),
        actions, ...feedback(3), ...feeLines(3))));
}

// The live example for builders: does this wallet pass the example third-party quest?
function renderHolder() {
  const c = net.contracts;
  const links = $("builder-links");
  if (!c) { links.replaceChildren(); return; }
  links.replaceChildren(
    el("a", { href: addrUrl(c.questRegistry), target: "_blank", rel: "noopener noreferrer" }, "QuestRegistry"),
    " · ",
    el("a", { href: addrUrl(c.holderQuest), target: "_blank", rel: "noopener noreferrer" }, "Example Holder quest"));
  $("safe-links").replaceChildren(
    el("a", { href: addrUrl(c.questRegistry), target: "_blank", rel: "noopener noreferrer" }, "registry"),
    ", ",
    el("a", { href: addrUrl(c.depositQuest), target: "_blank", rel: "noopener noreferrer" }, "deposit contract"),
    ", ",
    el("a", { href: addrUrl(c.questBadge), target: "_blank", rel: "noopener noreferrer" }, "badge"));
}

// The page redraws whole sections after every change. Without this, keyboard focus would fall back
// to the top of the page each time. Put it back on the same button, or on the next logical place.
function render() {
  const key = document.activeElement?.dataset?.focusKey ?? null;
  renderToolbar();
  renderBanner();
  renderHero();
  renderQuests();
  renderBadge();
  renderHolder();
  renderRegister();
  renderFees();
  renderCommunity();
  if (!key) return;
  const same = document.querySelector(`[data-focus-key="${key}"]`);
  const next = document.querySelector('.quest.active [data-focus-key], [data-focus-key="badge"]');
  (same ?? next)?.focus({ preventScroll: true });
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
  $("register-form").addEventListener("submit", (e) => { e.preventDefault(); doRegister(); });
  let typing;
  $("reg-address").addEventListener("input", () => { clearTimeout(typing); typing = setTimeout(previewQuest, 400); });
  $("community-more").addEventListener("click", async () => { S.community.shown += 10; await loadCommunity(); });
  if (net.contracts) loadCommunity(); // anyone can browse the community quests, even without a wallet
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
