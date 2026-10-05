// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";
import {QuestBadge} from "../src/QuestBadge.sol";
import {RegisterQuest} from "../src/quests/RegisterQuest.sol";
import {DepositQuest} from "../src/quests/DepositQuest.sol";
import {WithdrawQuest} from "../src/quests/WithdrawQuest.sol";
import {HolderQuest, IERC20Balance} from "../src/examples/HolderQuest.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {RevertingQuest} from "./QuestRegistry.t.sol";

/// @dev Shared setup: the real three quests, wired into a real registry.
abstract contract JourneyBase is Test {
    MockUSDC usdc;
    RegisterQuest registerQuest;
    DepositQuest depositQuest;
    WithdrawQuest withdrawQuest;
    QuestRegistry registry;
    QuestBadge badge;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 constant AMOUNT = 10_000; // 0.01 USDC

    function setUp() public virtual {
        usdc = new MockUSDC();
        registerQuest = new RegisterQuest();
        depositQuest = new DepositQuest(IERC20(address(usdc)));
        withdrawQuest = new WithdrawQuest(depositQuest);
        IQuest[3] memory builtIn = [IQuest(registerQuest), IQuest(depositQuest), IQuest(withdrawQuest)];
        string[3] memory names = ["Join", "Deposit 0.01 USDC", "Withdraw"];
        string[3] memory descs = ["Join Open Quest", "Deposit 0.01 USDC", "Take your deposit back"];
        registry = new QuestRegistry(builtIn, names, descs);
        badge = registry.badge();
        usdc.mint(alice, 1_000_000);
        usdc.mint(bob, 1_000_000);
    }

    function _deposit(address user) internal {
        vm.startPrank(user);
        usdc.approve(address(depositQuest), AMOUNT);
        depositQuest.deposit();
        vm.stopPrank();
    }

    function _completeAll(address user) internal {
        vm.prank(user);
        registerQuest.join();
        _deposit(user);
        vm.prank(user);
        depositQuest.withdraw();
    }
}

contract RegisterQuestTest is JourneyBase {
    function test_joinHappyPath() public {
        assertFalse(registerQuest.check(alice));
        vm.prank(alice);
        registerQuest.join();
        assertTrue(registerQuest.check(alice));
        assertFalse(registerQuest.check(bob)); // someone else's progress is unaffected
    }

    function test_doubleJoinReverts() public {
        vm.startPrank(alice);
        registerQuest.join();
        vm.expectRevert(RegisterQuest.AlreadyJoined.selector);
        registerQuest.join();
        vm.stopPrank();
    }
}

contract DepositQuestTest is JourneyBase {
    function test_depositHappyPath() public {
        assertFalse(depositQuest.check(alice));
        _deposit(alice);
        assertTrue(depositQuest.check(alice));
        assertEq(depositQuest.balanceOf(alice), AMOUNT);
        assertEq(usdc.balanceOf(address(depositQuest)), AMOUNT);
        assertEq(usdc.balanceOf(alice), 1_000_000 - AMOUNT);
    }

    function test_depositWithoutApprovalReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        depositQuest.deposit();
        assertFalse(depositQuest.check(alice));
    }

    function test_secondDepositReverts() public {
        _deposit(alice);
        vm.startPrank(alice);
        usdc.approve(address(depositQuest), AMOUNT);
        vm.expectRevert(DepositQuest.AlreadyDeposited.selector);
        depositQuest.deposit();
        vm.stopPrank();
    }

    function test_depositorGetsFullDepositBack() public {
        _deposit(alice);
        vm.prank(alice);
        depositQuest.withdraw();
        assertEq(usdc.balanceOf(alice), 1_000_000);
        assertEq(usdc.balanceOf(address(depositQuest)), 0);
        assertEq(depositQuest.balanceOf(alice), 0);
        assertTrue(depositQuest.withdrawn(alice));
    }

    function test_withdrawBeforeDepositReverts() public {
        vm.prank(alice);
        vm.expectRevert(DepositQuest.NothingToWithdraw.selector);
        depositQuest.withdraw();
        assertFalse(depositQuest.withdrawn(alice));
    }

    function test_withdrawTwiceReverts() public {
        _deposit(alice);
        vm.startPrank(alice);
        depositQuest.withdraw();
        vm.expectRevert(DepositQuest.NothingToWithdraw.selector);
        depositQuest.withdraw();
        vm.stopPrank();
    }

    /// Nobody can touch another wallet's deposit.
    function test_otherWalletCannotWithdrawMyDeposit() public {
        _deposit(alice);
        vm.prank(bob);
        vm.expectRevert(DepositQuest.NothingToWithdraw.selector);
        depositQuest.withdraw();
        assertEq(depositQuest.balanceOf(alice), AMOUNT);
    }

    /// Deposits stay withdrawable even if the other quests do something odd.
    function test_withdrawWorksWithoutAnyOtherContract() public {
        _deposit(alice); // never joined, never registered anywhere else
        vm.prank(alice);
        depositQuest.withdraw();
        assertEq(usdc.balanceOf(alice), 1_000_000);
    }
}

contract WithdrawQuestTest is JourneyBase {
    function test_onlyTrueAfterDepositThenWithdraw() public {
        assertFalse(withdrawQuest.check(alice));
        _deposit(alice);
        assertFalse(withdrawQuest.check(alice)); // deposited but not withdrawn
        vm.prank(alice);
        depositQuest.withdraw();
        assertTrue(withdrawQuest.check(alice));
    }

    function test_neverTrueWithoutDeposit() public view {
        assertFalse(withdrawQuest.check(bob));
    }
}

/// @dev A token that tries to call `withdraw()` again while it is sending funds back.
contract ReentrantToken is MockUSDC {
    DepositQuest public target;
    bool public attacking;

    function arm(DepositQuest target_) external {
        target = target_;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (address(target) != address(0) && !attacking) {
            attacking = true;
            target.withdraw(); // re-enter
        }
        return super.transfer(to, amount);
    }
}

contract DepositQuestReentrancyTest is Test {
    function test_reentrantWithdrawIsBlocked() public {
        ReentrantToken token = new ReentrantToken();
        DepositQuest vault = new DepositQuest(IERC20(address(token)));
        address attacker = makeAddr("attacker");
        token.mint(attacker, 1_000_000);
        token.mint(address(vault), 1_000_000); // other people's money sits in the vault

        vm.startPrank(attacker);
        token.approve(address(vault), 10_000);
        vault.deposit();
        token.arm(vault);
        vm.expectRevert(); // the re-entry reverts, so the whole withdrawal reverts
        vault.withdraw();
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 1_010_000); // nothing left the vault
        assertEq(vault.balanceOf(attacker), 10_000);
    }
}

contract QuestBadgeTest is JourneyBase {
    function test_claimBadgeHappyPath() public {
        _completeAll(alice);
        bool[3] memory p = registry.builtInProgress(alice);
        assertTrue(p[0] && p[1] && p[2]);

        vm.prank(alice);
        registry.claimBadge();

        uint256 id = badge.tokenIdOf(alice);
        assertEq(badge.ownerOf(id), alice);
        assertEq(badge.levelOf(id), 3);
        assertTrue(badge.hasBadge(alice));
        assertTrue(badge.locked(id));
        assertTrue(badge.supportsInterface(0xb45a3c0e)); // ERC-5192
        assertEq(badge.balanceOf(alice), 1);
    }

    function test_claimTooEarlyRevertsNamingTheMissingQuest() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(QuestRegistry.QuestNotComplete.selector, 0));
        registry.claimBadge();

        vm.prank(alice);
        registerQuest.join();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(QuestRegistry.QuestNotComplete.selector, 1));
        registry.claimBadge();

        _deposit(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(QuestRegistry.QuestNotComplete.selector, 2));
        registry.claimBadge();
        assertFalse(badge.hasBadge(alice));
    }

    function test_claimTwiceReverts() public {
        _completeAll(alice);
        vm.startPrank(alice);
        registry.claimBadge();
        vm.expectRevert(QuestRegistry.AlreadyClaimed.selector);
        registry.claimBadge();
        vm.stopPrank();
        assertEq(badge.balanceOf(alice), 1);
    }

    function test_transferringTheBadgeReverts() public {
        _completeAll(alice);
        vm.prank(alice);
        registry.claimBadge();
        uint256 id = badge.tokenIdOf(alice);

        vm.startPrank(alice);
        vm.expectRevert(QuestBadge.Soulbound.selector);
        badge.transferFrom(alice, bob, id);
        vm.expectRevert(QuestBadge.Soulbound.selector);
        badge.safeTransferFrom(alice, bob, id);
        vm.expectRevert(QuestBadge.Soulbound.selector);
        badge.safeTransferFrom(alice, bob, id, "");
        vm.stopPrank();

        // An approved operator cannot move it either.
        vm.prank(alice);
        badge.approve(bob, id);
        vm.prank(bob);
        vm.expectRevert(QuestBadge.Soulbound.selector);
        badge.transferFrom(alice, bob, id);

        assertEq(badge.ownerOf(id), alice);
    }

    function test_onlyRegistryCanMint() public {
        vm.prank(alice);
        vm.expectRevert(QuestBadge.NotRegistry.selector);
        badge.mint(alice, 3);
    }

    function test_tokenUriIsOnChainJson() public {
        _completeAll(alice);
        vm.prank(alice);
        registry.claimBadge();
        string memory uri = badge.tokenURI(badge.tokenIdOf(alice));
        assertEq(bytes(uri).length > 40, true);
        assertEq(_startsWith(uri, "data:application/json;base64,"), true);
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory a = bytes(s);
        bytes memory b = bytes(prefix);
        if (a.length < b.length) return false;
        for (uint256 i = 0; i < b.length; i++) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }
}

contract ThirdPartyQuestTest is JourneyBase {
    /// A builder registers a custom quest; the whole registry keeps working and the badge is unaffected.
    function test_customThirdPartyQuestRegistersAndShowsStatus() public {
        HolderQuest holder = new HolderQuest(IERC20Balance(address(usdc)), 1_000_000);
        vm.prank(bob);
        uint256 id = registry.registerQuest(address(holder), "Holder", "Hold 1 USDC");
        assertEq(id, 3);
        assertTrue(registry.isComplete(id, alice)); // alice holds 1 USDC
        assertFalse(registry.isComplete(id, makeAddr("empty")));
    }

    function test_hostileThirdPartyQuestCannotBlockOrFakeABadge() public {
        RevertingQuest bad = new RevertingQuest();
        registry.registerQuest(address(bad), "bad", "always reverts");

        // Not completing built-ins still fails, regardless of third-party quests.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(QuestRegistry.QuestNotComplete.selector, 0));
        registry.claimBadge();

        // Completing built-ins still works with a hostile quest registered.
        _completeAll(alice);
        vm.prank(alice);
        registry.claimBadge();
        assertTrue(badge.hasBadge(alice));
    }
}
