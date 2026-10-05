// Open Quest: the page logic. No build step; ethers v6 is loaded from a pinned CDN file (see index.html).
// The page reads everything from the chain, so a reopened page always shows the real state.
import { NETWORKS, DEFAULT_NETWORK, ABI } from "./config.js";

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
  readProvider: null,
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
    S.state = "ready";
  } catch (e) {
    console.error(e);
    S.state = "error";
  }
  render();
}

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

function renderQuests() {
  const list = $("quests");
  list.replaceChildren(
    ...QUESTS.map((q, i) => {
      const st = questState(i);
      const stateLine =
        st === "done"
          ? el("p", { class: "state" }, el("span", { class: "check", "aria-hidden": "true" }, "✓"), "Done")
          : st === "active"
            ? el("p", { class: "state" }, "Your next step")
            : el("p", { class: "state" }, el("span", { "aria-hidden": "true" }, "🔒"), lockedReason(i));
      return el(
        "li",
        { class: `quest ${st}`, "data-quest": String(i) },
        el("div", { class: "num", "aria-hidden": "true" }, String(i + 1)),
        el("div", {}, el("h3", {}, q.title), el("p", { class: "muted" }, q.text), stateLine, el("div", { class: "actions", id: `actions-${i}` })),
      );
    }),
  );
}

function render() {
  renderToolbar();
  renderBanner();
  renderQuests();
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
