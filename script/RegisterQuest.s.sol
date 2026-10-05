// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";

/// @notice Registers an already deployed quest contract in the Open Quest registry. Anyone can do this.
/// @dev Usage (from your own wallet; the key is read from the PRIVATE_KEY environment variable):
///        QUEST=0xYourQuest NAME="My quest" DESCRIPTION="What to do" \
///        forge script script/RegisterQuest.s.sol --rpc-url arc_mainnet --broadcast
///      The registry address comes from deployments/<chainId>.json, or set REGISTRY to override it.
///      Without --broadcast this is a dry run: nothing is sent.
contract RegisterQuestScript is Script {
    function run() external {
        address quest = vm.envAddress("QUEST");
        string memory name = vm.envString("NAME");
        string memory description = vm.envOr("DESCRIPTION", string(""));
        address registryAddress = vm.envOr("REGISTRY", address(0));
        if (registryAddress == address(0)) {
            string memory path = string.concat("./deployments/", vm.toString(block.chainid), ".json");
            registryAddress = vm.parseJsonAddress(vm.readFile(path), ".questRegistry");
        }
        QuestRegistry registry = QuestRegistry(registryAddress);

        console.log("Chain id:", block.chainid);
        console.log("Registry:", registryAddress);
        console.log("Quest:   ", quest);
        console.log("Name:    ", name);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        uint256 id = registry.registerQuest(quest, name, description);
        vm.stopBroadcast();

        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            console.log("Registered as quest id:", id);
        } else {
            console.log("Dry run only: nothing was sent. It would be quest id:", id);
        }
    }
}
