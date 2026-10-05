// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IQuest} from "./IQuest.sol";

/// @title QuestRegistry
/// @notice An open list of quests. Anyone can register a quest; the first three
///         ("built-in") quests are fixed at deployment and can never change.
/// @dev No owner, no admin, no upgrades. The registry never relies on third-party
///      quests for anything that moves value or mints: it only reads them.
contract QuestRegistry {
    struct QuestInfo {
        address quest;
        address registrant;
        string name;
        string description;
    }

    uint256 public constant BUILT_IN_COUNT = 3;
    uint256 public constant MAX_NAME_BYTES = 64;
    uint256 public constant MAX_DESCRIPTION_BYTES = 280;
    /// @dev Gas given to a third-party `check` when only reading it.
    uint256 public constant CHECK_GAS_LIMIT = 100_000;

    QuestInfo[] private _quests;
    mapping(address quest => bool) public isRegistered;

    event QuestRegistered(uint256 indexed id, address indexed quest, address indexed registrant, string name);

    error InvalidQuestAddress();
    error AlreadyRegistered();
    error NameTooLong();
    error DescriptionTooLong();
    error UnknownQuest();

    /// @param builtIn The three built-in quests, in order: join, deposit, withdraw.
    /// @param names Their display names.
    /// @param descriptions Their short descriptions.
    constructor(IQuest[BUILT_IN_COUNT] memory builtIn, string[BUILT_IN_COUNT] memory names, string[BUILT_IN_COUNT] memory descriptions) {
        for (uint256 i = 0; i < BUILT_IN_COUNT; i++) {
            _register(address(builtIn[i]), names[i], descriptions[i], msg.sender);
        }
    }

    /// @notice Register any contract that implements `IQuest`. Open to everyone.
    /// @dev The quest is not called here. It can only ever be read, never trusted.
    function registerQuest(address quest, string calldata name, string calldata description) external returns (uint256 id) {
        return _register(quest, name, description, msg.sender);
    }

    function questCount() external view returns (uint256) {
        return _quests.length;
    }

    function getQuest(uint256 id) external view returns (QuestInfo memory) {
        if (id >= _quests.length) revert UnknownQuest();
        return _quests[id];
    }

    /// @notice Read-only: has `user` completed quest `id`?
    /// @dev A broken or hostile quest (reverts, burns gas, returns junk) counts as "not complete".
    function isComplete(uint256 id, address user) external view returns (bool) {
        if (id >= _quests.length) revert UnknownQuest();
        return _safeCheck(_quests[id].quest, user);
    }

    function _register(address quest, string memory name, string memory description, address registrant)
        private
        returns (uint256 id)
    {
        if (quest == address(0) || quest.code.length == 0) revert InvalidQuestAddress();
        if (isRegistered[quest]) revert AlreadyRegistered();
        if (bytes(name).length > MAX_NAME_BYTES) revert NameTooLong();
        if (bytes(description).length > MAX_DESCRIPTION_BYTES) revert DescriptionTooLong();

        isRegistered[quest] = true;
        id = _quests.length;
        _quests.push(QuestInfo(quest, registrant, name, description));
        emit QuestRegistered(id, quest, registrant, name);
    }

    function _safeCheck(address quest, address user) private view returns (bool) {
        try IQuest(quest).check{gas: CHECK_GAS_LIMIT}(user) returns (bool done) {
            return done;
        } catch {
            return false;
        }
    }
}
