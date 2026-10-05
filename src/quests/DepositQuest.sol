// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IQuest} from "../IQuest.sol";

/// @title DepositQuest
/// @notice Quest 2: deposit 0.01 USDC. The only contract in Open Quest that holds funds.
/// @dev Each wallet can deposit once and can always take its own deposit back with
///      `withdraw()`. There is no owner, admin, pause switch or upgrade path, and no
///      function sends funds to anyone except the depositor.
contract DepositQuest is IQuest, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 0.01 USDC. The USDC ERC-20 interface has 6 decimals.
    uint256 public constant DEPOSIT_AMOUNT = 10_000;

    IERC20 public immutable usdc;

    mapping(address user => bool) public deposited;
    mapping(address user => bool) public withdrawn;
    mapping(address user => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error AlreadyDeposited();
    error NothingToWithdraw();

    constructor(IERC20 usdc_) {
        usdc = usdc_;
    }

    /// @notice Pull 0.01 USDC from the caller (they must `approve` this contract first).
    function deposit() external nonReentrant {
        if (deposited[msg.sender]) revert AlreadyDeposited();
        // Effects first, then the token transfer.
        deposited[msg.sender] = true;
        balanceOf[msg.sender] = DEPOSIT_AMOUNT;
        usdc.safeTransferFrom(msg.sender, address(this), DEPOSIT_AMOUNT);
        emit Deposited(msg.sender, DEPOSIT_AMOUNT);
    }

    /// @notice Take your own deposit back. Works at any time while you have one.
    function withdraw() external nonReentrant {
        uint256 amount = balanceOf[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        // Effects first, then the token transfer.
        balanceOf[msg.sender] = 0;
        withdrawn[msg.sender] = true;
        usdc.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function check(address user) external view returns (bool) {
        return deposited[user];
    }
}
