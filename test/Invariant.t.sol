// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";
import {QuestBadge} from "../src/QuestBadge.sol";
import {RegisterQuest} from "../src/quests/RegisterQuest.sol";
import {DepositQuest} from "../src/quests/DepositQuest.sol";
import {WithdrawQuest} from "../src/quests/WithdrawQuest.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @dev Random wallets call random quest actions, in any order, with or without success.
contract Handler is Test {
    MockUSDC public usdc;
    RegisterQuest public registerQuest;
    DepositQuest public depositQuest;
    QuestRegistry public registry;
    QuestBadge public badge;

    address[] public actors;
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public claims;

    constructor(MockUSDC usdc_, RegisterQuest r, DepositQuest d, QuestRegistry reg) {
        usdc = usdc_;
        registerQuest = r;
        depositQuest = d;
        registry = reg;
        badge = reg.badge();
        for (uint256 i = 0; i < 5; i++) {
            address a = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(a);
            usdc.mint(a, 1_000_000);
        }
    }

    function actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function join(uint256 seed) external {
        vm.prank(actor(seed));
        try registerQuest.join() {} catch {}
    }

    function deposit(uint256 seed) external {
        address a = actor(seed);
        vm.startPrank(a);
        usdc.approve(address(depositQuest), 10_000);
        try depositQuest.deposit() { deposits++; } catch {}
        vm.stopPrank();
    }

    function withdraw(uint256 seed) external {
        vm.prank(actor(seed));
        try depositQuest.withdraw() { withdrawals++; } catch {}
    }

    function claim(uint256 seed) external {
        vm.prank(actor(seed));
        try registry.claimBadge() { claims++; } catch {}
    }

    /// An attacker (not one of the actors) tries to move someone's deposit: must always fail.
    function stealAttempt(uint256 seed) external {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        try depositQuest.withdraw() { revert("attacker withdrew funds"); } catch {}
        seed;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }
}

contract InvariantTest is StdInvariant, Test {
    MockUSDC usdc;
    RegisterQuest registerQuest;
    DepositQuest depositQuest;
    WithdrawQuest withdrawQuest;
    QuestRegistry registry;
    QuestBadge badge;
    Handler handler;

    function setUp() public {
        usdc = new MockUSDC();
        registerQuest = new RegisterQuest();
        depositQuest = new DepositQuest(IERC20(address(usdc)));
        withdrawQuest = new WithdrawQuest(depositQuest);
        IQuest[3] memory b = [IQuest(registerQuest), IQuest(depositQuest), IQuest(withdrawQuest)];
        string[3] memory n = ["Join", "Deposit", "Withdraw"];
        registry = new QuestRegistry(b, n, n);
        badge = registry.badge();
        handler = new Handler(usdc, registerQuest, depositQuest, registry);
        targetContract(address(handler));
    }

    /// The vault holds exactly 0.01 USDC for every deposit that has not been withdrawn. Nothing leaks, nothing is stuck.
    function invariant_vaultHoldsExactlyTheLiveDeposits() public view {
        uint256 live = handler.deposits() - handler.withdrawals();
        assertEq(usdc.balanceOf(address(depositQuest)), live * depositQuest.DEPOSIT_AMOUNT());
    }

    /// Every wallet's recorded balance is either 0 or exactly one deposit.
    function invariant_perWalletBalanceIsZeroOrOneDeposit() public view {
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            uint256 bal = depositQuest.balanceOf(handler.actors(i));
            assertTrue(bal == 0 || bal == depositQuest.DEPOSIT_AMOUNT());
        }
    }

    /// A wallet that withdrew always deposited first, and a wallet with a live deposit has not withdrawn.
    function invariant_withdrawnImpliesDeposited() public view {
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            address a = handler.actors(i);
            if (depositQuest.withdrawn(a)) assertTrue(depositQuest.deposited(a));
            if (depositQuest.balanceOf(a) > 0) assertFalse(depositQuest.withdrawn(a));
        }
    }

    /// Only wallets that finished all three quests ever hold a badge, at most one each, always at level 3.
    function invariant_badgesOnlyForFinishedWalletsAtMostOne() public view {
        uint256 holders;
        for (uint256 i = 0; i < handler.actorCount(); i++) {
            address a = handler.actors(i);
            uint256 n = badge.balanceOf(a);
            assertLe(n, 1);
            if (n == 1) {
                holders++;
                assertTrue(registerQuest.check(a) && depositQuest.check(a) && withdrawQuest.check(a));
                assertEq(badge.levelOf(badge.tokenIdOf(a)), 3);
            }
        }
        assertEq(holders, handler.claims());
    }
}
