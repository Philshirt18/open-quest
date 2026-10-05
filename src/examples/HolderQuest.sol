// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IQuest} from "../IQuest.sol";

interface IERC20Balance {
    function balanceOf(address account) external view returns (uint256);
}

/// @title HolderQuest
/// @notice Example third-party quest: "hold at least `minBalance` of a token".
/// @dev This is all a quest needs: implement `check`, then call `registry.registerQuest(...)`.
contract HolderQuest is IQuest {
    IERC20Balance public immutable token;
    uint256 public immutable minBalance;

    constructor(IERC20Balance token_, uint256 minBalance_) {
        token = token_;
        minBalance = minBalance_;
    }

    function check(address user) external view returns (bool) {
        return token.balanceOf(user) >= minBalance;
    }
}
