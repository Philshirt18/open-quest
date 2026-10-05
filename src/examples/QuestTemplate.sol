// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IQuest} from "../IQuest.sol";

/// @title QuestTemplate
/// @notice Copy this file, rename the contract, and change the one line marked CHANGE ME.
///
/// A quest is any contract with ONE function: `check(address user)` -> true when the wallet has done
/// the thing. Keep it a cheap read (no state changes, no loops over big lists), because the registry
/// reads it with a gas limit of 100,000 and treats anything other than an exact `true` as "not done".
///
/// Ideas that can be checked from on-chain state alone:
///   - holds a token or NFT:          token.balanceOf(user) >= 1
///   - has deposited into your app:   yourApp.deposited(user)
///   - has voted / staked / joined:   yourApp.hasVoted(user)
contract QuestTemplate is IQuest {
    function check(address user) external view returns (bool) {
        return user.balance > 0; // CHANGE ME: your rule, e.g. "has any USDC at all"
    }
}
