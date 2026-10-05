// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IQuest} from "../IQuest.sol";

/// @title RegisterQuest
/// @notice Quest 1: call `join()` once. That's it.
contract RegisterQuest is IQuest {
    mapping(address user => bool) public joined;

    event Joined(address indexed user);

    error AlreadyJoined();

    function join() external {
        if (joined[msg.sender]) revert AlreadyJoined();
        joined[msg.sender] = true;
        emit Joined(msg.sender);
    }

    function check(address user) external view returns (bool) {
        return joined[user];
    }
}
