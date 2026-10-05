// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";
import {RegisterQuest} from "../src/quests/RegisterQuest.sol";
import {DepositQuest} from "../src/quests/DepositQuest.sol";
import {WithdrawQuest} from "../src/quests/WithdrawQuest.sol";
import {HolderQuest, IERC20Balance} from "../src/examples/HolderQuest.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

/// @notice Deploys all of Open Quest and registers the example Holder quest.
/// @dev The deployer key is read from the PRIVATE_KEY environment variable. Never put a key in this file.
///      Addresses are printed and written to deployments/<chainId>.json.
contract Deploy is Script {
    // Official Arc values: https://docs.arc.io/arc/references/connect-to-arc
    uint256 constant ARC_MAINNET = 5042;
    uint256 constant ARC_TESTNET = 5042002;
    uint256 constant LOCAL = 31337;
    // USDC ERC-20 interface on Arc (6 decimals): https://docs.arc.io/arc/references/contract-addresses
    address constant ARC_USDC = 0x3600000000000000000000000000000000000000;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console.log("Chain id:", block.chainid);
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);

        address usdc = _usdc();

        RegisterQuest registerQuest = new RegisterQuest();
        DepositQuest depositQuest = new DepositQuest(IERC20(usdc));
        WithdrawQuest withdrawQuest = new WithdrawQuest(depositQuest);

        IQuest[3] memory builtIn = [IQuest(registerQuest), IQuest(depositQuest), IQuest(withdrawQuest)];
        string[3] memory names = ["Join Open Quest", "Deposit 0.01 USDC", "Withdraw your deposit"];
        string[3] memory descriptions = [
            "Say hello on Arc: call join() once.",
            "Deposit 0.01 USDC. You can take it back at any time.",
            "Take your 0.01 USDC deposit back."
        ];
        QuestRegistry registry = new QuestRegistry(builtIn, names, descriptions);

        // The example third-party quest, registered through the same open function anyone can use.
        HolderQuest holder = new HolderQuest(IERC20Balance(usdc), 1_000_000); // 1 USDC
        uint256 holderId = registry.registerQuest(address(holder), "Holder quest", "Hold at least 1 USDC.");

        vm.stopBroadcast();

        console.log("USDC:          ", usdc);
        console.log("RegisterQuest: ", address(registerQuest));
        console.log("DepositQuest:  ", address(depositQuest));
        console.log("WithdrawQuest: ", address(withdrawQuest));
        console.log("QuestRegistry: ", address(registry));
        console.log("QuestBadge:    ", address(registry.badge()));
        console.log("HolderQuest:   ", address(holder));
        console.log("Holder quest id:", holderId);

        string memory k = "deployment";
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeAddress(k, "usdc", usdc);
        vm.serializeAddress(k, "registerQuest", address(registerQuest));
        vm.serializeAddress(k, "depositQuest", address(depositQuest));
        vm.serializeAddress(k, "withdrawQuest", address(withdrawQuest));
        vm.serializeAddress(k, "questRegistry", address(registry));
        vm.serializeAddress(k, "questBadge", address(registry.badge()));
        vm.serializeUint(k, "holderQuestId", holderId);
        string memory json = vm.serializeAddress(k, "holderQuest", address(holder));
        vm.writeJson(json, string.concat("./deployments/", vm.toString(block.chainid), ".json"));
    }

    /// @dev Local chain: deploy a mock USDC. Arc: the official USDC. Anything else needs USDC_ADDRESS.
    function _usdc() internal returns (address) {
        if (block.chainid == LOCAL) {
            return address(new MockUSDC());
        }
        address configured = vm.envOr("USDC_ADDRESS", address(0));
        if (configured != address(0)) return configured;
        require(block.chainid == ARC_MAINNET || block.chainid == ARC_TESTNET, "Unknown chain: set USDC_ADDRESS");
        return ARC_USDC;
    }
}
