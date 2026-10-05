// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IQuest
/// @notice The one function a contract needs to become a quest in Open Quest.
interface IQuest {
    /// @notice Has `user` completed this quest?
    /// @dev Must be a cheap, read-only check. The registry calls it with a gas limit.
    function check(address user) external view returns (bool);
}
