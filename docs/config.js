// Open Quest: the single config file for the page.
// Network values come from the official Arc docs and were checked against the live RPC (eth_chainId) on 2026-10-05.
//   Network values:  https://docs.arc.io/arc/references/connect-to-arc
//   USDC address:    https://docs.arc.io/arc/references/contract-addresses
//   Native USDC gas uses 18 decimals; the USDC ERC-20 interface uses 6 decimals.
//   Faucet (testnet only): https://faucet.circle.com
// Deployed contract addresses are filled in by the build after each deployment.

export const NETWORKS = {
  mainnet: {
    key: "mainnet",
    chainId: 5042,
    chainIdHex: "0x13b2",
    name: "Arc",
    rpcUrl: "https://rpc.mainnet.arc.io",
    explorerUrl: "https://explorer.arc.io",
    nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
    faucetUrl: null,
    // Filled in after the mainnet deployment (done by the project owner).
    contracts: null,
  },
  testnet: {
    key: "testnet",
    chainId: 5042002,
    chainIdHex: "0x4cef52",
    name: "Arc Testnet",
    rpcUrl: "https://rpc.testnet.arc.io",
    explorerUrl: "https://explorer.testnet.arc.io",
    nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
    faucetUrl: "https://faucet.circle.com",
    // Deployed on 2026-10-05 (rehearsal).
    contracts: {
      usdc: "0x3600000000000000000000000000000000000000",
      registerQuest: "0x86C8a54b61fdDCBf301E058B3FE3d95d769F32dE",
      depositQuest: "0x4e275F30DeC3820aC6628F9b72a323dfEB499B57",
      withdrawQuest: "0x509905d40e0958A168Ff6F102E37c89Dc1Ef979d",
      questRegistry: "0xd36F79CCE81e66bBaba3950abF619712464d8Cae",
      questBadge: "0x635C1EA6915BA6016216F4B0173880f49aC5C224",
      holderQuest: "0x90D345aB83020523bae46867d53a5467Db363C72",
      holderQuestId: 3,
    },
  },
};

// Which network the page uses. Mainnet is the real one; testnet is for rehearsal.
// The page also accepts ?network=testnet in the address bar.
export const DEFAULT_NETWORK = "testnet";

export const USDC_DECIMALS = 6; // ERC-20 interface
export const DEPOSIT_AMOUNT = 10000n; // 0.01 USDC in 6-decimal units

// Human-readable ABIs (ethers v6) for exactly the functions the page uses.
export const ABI = {
  registry: [
    "function builtInProgress(address user) view returns (bool[3])",
    "function isComplete(uint256 id, address user) view returns (bool)",
    "function questCount() view returns (uint256)",
    "function getQuest(uint256 id) view returns (tuple(address quest, address registrant, string name, string description))",
    "function claimBadge()",
    "function registerQuest(address quest, string name, string description) returns (uint256)",
  ],
  register: ["function join()"],
  deposit: [
    "function deposit()",
    "function withdraw()",
    "function balanceOf(address) view returns (uint256)",
  ],
  usdc: [
    "function balanceOf(address) view returns (uint256)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
  ],
  badge: [
    "function hasBadge(address owner) view returns (bool)",
    "function tokenIdOf(address owner) pure returns (uint256)",
    "function levelOf(uint256 tokenId) view returns (uint8)",
    "function tokenURI(uint256 tokenId) view returns (string)",
  ],
};
