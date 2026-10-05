// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IQuest} from "../IQuest.sol";
import {DepositQuest} from "./DepositQuest.sol";

/// @title WithdrawQuest
/// @notice Quest 3: get your deposit back.
/// @dev Holds no funds. The withdrawal itself lives in `DepositQuest.withdraw()`, next to
///      the money, so it can never be blocked by another contract. This quest only checks
///      that a real deposit was followed by a real withdrawal.
contract WithdrawQuest is IQuest {
    DepositQuest public immutable vault;

    constructor(DepositQuest vault_) {
        vault = vault_;
    }

    function check(address user) external view returns (bool) {
        return vault.withdrawn(user);
    }
}
