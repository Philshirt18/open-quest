// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";
import {HolderQuest, IERC20Balance} from "../src/examples/HolderQuest.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @dev Always-true quest, used as a stand-in for the built-in quests in this slice.
contract AlwaysTrueQuest is IQuest {
    function check(address) external pure returns (bool) {
        return true;
    }
}

/// @dev Hostile quest: reverts.
contract RevertingQuest is IQuest {
    function check(address) external pure returns (bool) {
        revert("nope");
    }
}

/// @dev Hostile quest: tries to burn all the gas it is given.
contract GasBurnerQuest is IQuest {
    function check(address) external view returns (bool) {
        while (true) {}
        return true;
    }
}

contract QuestRegistryTest is Test {
    QuestRegistry registry;
    MockUSDC usdc;
    address alice = makeAddr("alice");
    address builder = makeAddr("builder");

    function setUp() public {
        usdc = new MockUSDC();
        IQuest[3] memory builtIn = [IQuest(new AlwaysTrueQuest()), IQuest(new AlwaysTrueQuest()), IQuest(new AlwaysTrueQuest())];
        string[3] memory names = ["Join", "Deposit", "Withdraw"];
        string[3] memory descs = ["join it", "deposit", "withdraw"];
        registry = new QuestRegistry(builtIn, names, descs);
    }

    function test_builtInQuestsArePreRegistered() public view {
        assertEq(registry.questCount(), 3);
        assertEq(registry.getQuest(0).name, "Join");
        assertEq(registry.getQuest(2).name, "Withdraw");
    }

    /// A third-party builder registers their own quest with no permission from anyone.
    function test_thirdPartyCanRegisterCustomQuest() public {
        HolderQuest holder = new HolderQuest(IERC20Balance(address(usdc)), 1_000_000);

        vm.prank(builder);
        uint256 id = registry.registerQuest(address(holder), "Holder", "Hold at least 1 USDC");

        assertEq(id, 3);
        assertEq(registry.questCount(), 4);
        assertEq(registry.getQuest(id).registrant, builder);
        assertTrue(registry.isRegistered(address(holder)));

        assertFalse(registry.isComplete(id, alice));
        usdc.mint(alice, 1_000_000);
        assertTrue(registry.isComplete(id, alice));
    }

    function test_registerEmitsEvent() public {
        AlwaysTrueQuest q = new AlwaysTrueQuest();
        vm.expectEmit(true, true, true, true);
        emit QuestRegistry.QuestRegistered(3, address(q), builder, "Mine");
        vm.prank(builder);
        registry.registerQuest(address(q), "Mine", "desc");
    }

    function test_rejectsZeroAddress() public {
        vm.expectRevert(QuestRegistry.InvalidQuestAddress.selector);
        registry.registerQuest(address(0), "x", "y");
    }

    function test_rejectsAddressWithoutCode() public {
        vm.expectRevert(QuestRegistry.InvalidQuestAddress.selector);
        registry.registerQuest(alice, "x", "y");
    }

    function test_rejectsDuplicateQuest() public {
        AlwaysTrueQuest q = new AlwaysTrueQuest();
        registry.registerQuest(address(q), "a", "b");
        vm.expectRevert(QuestRegistry.AlreadyRegistered.selector);
        registry.registerQuest(address(q), "a", "b");
    }

    function test_rejectsTooLongNameAndDescription() public {
        AlwaysTrueQuest q = new AlwaysTrueQuest();
        vm.expectRevert(QuestRegistry.NameTooLong.selector);
        registry.registerQuest(address(q), string(new bytes(65)), "d");
        vm.expectRevert(QuestRegistry.DescriptionTooLong.selector);
        registry.registerQuest(address(q), "n", string(new bytes(281)));
    }

    function test_unknownQuestIdReverts() public {
        vm.expectRevert(QuestRegistry.UnknownQuest.selector);
        registry.getQuest(99);
        vm.expectRevert(QuestRegistry.UnknownQuest.selector);
        registry.isComplete(99, alice);
    }

    /// A hostile quest that reverts counts as "not complete" and breaks nothing.
    function test_revertingQuestCountsAsNotComplete() public {
        RevertingQuest q = new RevertingQuest();
        uint256 id = registry.registerQuest(address(q), "bad", "reverts");
        assertFalse(registry.isComplete(id, alice));
        assertTrue(registry.isComplete(0, alice)); // other quests still readable
    }

    /// A hostile quest that burns all its gas is cut off at the gas limit.
    function test_gasBurningQuestIsCutOff() public {
        GasBurnerQuest q = new GasBurnerQuest();
        uint256 id = registry.registerQuest(address(q), "burner", "burns gas");
        uint256 before = gasleft();
        assertFalse(registry.isComplete(id, alice));
        assertLt(before - gasleft(), 200_000);
    }
}
