// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";

/// @notice Deploys a new QuestRegistry (which creates its own QuestBadge) on top of the quests that are
///         already deployed, and registers the existing example Holder quest in it.
/// @dev Reads the existing quest addresses from deployments/<chainId>.json. The three built-in quests and
///      the Holder quest are NOT redeployed, so wallets keep their quest progress. The previous registry and
///      badge stay on-chain, untouched, and are recorded in the file as previousRegistry / previousBadge.
///      The key is read from the PRIVATE_KEY environment variable. Nothing is written on a dry run.
contract RedeployRegistry is Script {
    struct Existing {
        address usdc;
        address registerQuest;
        address depositQuest;
        address withdrawQuest;
        address holderQuest;
        address registry;
        address badge;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        string memory path = string.concat("./deployments/", vm.toString(block.chainid), ".json");
        Existing memory e = _read(path);

        console.log("Chain id:", block.chainid);
        console.log("Deployer:", vm.addr(deployerKey));
        console.log("Reusing RegisterQuest:", e.registerQuest);
        console.log("Reusing DepositQuest: ", e.depositQuest);
        console.log("Reusing WithdrawQuest:", e.withdrawQuest);
        console.log("Reusing HolderQuest:  ", e.holderQuest);
        console.log("Previous registry:    ", e.registry);

        vm.startBroadcast(deployerKey);
        QuestRegistry registry = _deployRegistry(e);
        uint256 holderId = registry.registerQuest(e.holderQuest, "Holder quest", "Hold at least 1 USDC.");
        vm.stopBroadcast();

        console.log("New QuestRegistry:    ", address(registry));
        console.log("New QuestBadge:       ", address(registry.badge()));
        console.log("Holder quest id:", holderId);

        if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            console.log("Dry run only: nothing was deployed and no file was written.");
            return;
        }
        _write(path, e, registry, holderId);
    }

    function _read(string memory path) internal view returns (Existing memory e) {
        string memory json = vm.readFile(path);
        e.usdc = vm.parseJsonAddress(json, ".usdc");
        e.registerQuest = vm.parseJsonAddress(json, ".registerQuest");
        e.depositQuest = vm.parseJsonAddress(json, ".depositQuest");
        e.withdrawQuest = vm.parseJsonAddress(json, ".withdrawQuest");
        e.holderQuest = vm.parseJsonAddress(json, ".holderQuest");
        e.registry = vm.parseJsonAddress(json, ".questRegistry");
        e.badge = vm.parseJsonAddress(json, ".questBadge");
    }

    /// @dev Same names and descriptions as the first deployment.
    function _deployRegistry(Existing memory e) internal returns (QuestRegistry) {
        IQuest[3] memory builtIn = [IQuest(e.registerQuest), IQuest(e.depositQuest), IQuest(e.withdrawQuest)];
        string[3] memory names = ["Join Open Quest", "Deposit 0.01 USDC", "Withdraw your deposit"];
        string[3] memory descriptions = [
            "Say hello on Arc: call join() once.",
            "Deposit 0.01 USDC. You can take it back at any time.",
            "Take your 0.01 USDC deposit back."
        ];
        return new QuestRegistry(builtIn, names, descriptions);
    }

    function _write(string memory path, Existing memory e, QuestRegistry registry, uint256 holderId) internal {
        string memory k = "redeployment";
        vm.serializeUint(k, "chainId", block.chainid);
        vm.serializeAddress(k, "usdc", e.usdc);
        vm.serializeAddress(k, "registerQuest", e.registerQuest);
        vm.serializeAddress(k, "depositQuest", e.depositQuest);
        vm.serializeAddress(k, "withdrawQuest", e.withdrawQuest);
        vm.serializeAddress(k, "questRegistry", address(registry));
        vm.serializeAddress(k, "questBadge", address(registry.badge()));
        vm.serializeAddress(k, "previousRegistry", e.registry);
        vm.serializeAddress(k, "previousBadge", e.badge);
        vm.serializeUint(k, "holderQuestId", holderId);
        string memory json = vm.serializeAddress(k, "holderQuest", e.holderQuest);
        vm.writeJson(json, path);
    }
}
