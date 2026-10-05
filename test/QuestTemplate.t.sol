// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";
import {QuestTemplate} from "../src/examples/QuestTemplate.sol";

contract OkBuiltIn is IQuest {
    function check(address) external pure returns (bool) {
        return true;
    }
}

/// @dev What a builder does: deploy the template, register it, read the status through the registry.
contract QuestTemplateTest is Test {
    QuestRegistry registry;

    function setUp() public {
        IQuest[3] memory b = [IQuest(new OkBuiltIn()), IQuest(new OkBuiltIn()), IQuest(new OkBuiltIn())];
        string[3] memory n = ["a", "b", "c"];
        registry = new QuestRegistry(b, n, n);
    }

    function test_builderRegistersTheTemplateAndReadsStatus() public {
        QuestTemplate quest = new QuestTemplate();
        address builder = makeAddr("builder");
        address rich = makeAddr("rich");
        address poor = makeAddr("poor");
        vm.deal(rich, 1 ether);

        vm.prank(builder);
        uint256 id = registry.registerQuest(address(quest), "Has funds", "Hold any USDC on Arc.");

        assertEq(registry.getQuest(id).registrant, builder);
        assertTrue(registry.isComplete(id, rich));
        assertFalse(registry.isComplete(id, poor));
    }

    function test_templateStaysWithinTheRegistrysGasLimit() public {
        QuestTemplate quest = new QuestTemplate();
        uint256 before = gasleft();
        quest.check(address(this));
        assertLt(before - gasleft(), registry.CHECK_GAS_LIMIT());
    }
}
