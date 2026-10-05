// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IQuest} from "./IQuest.sol";
import {QuestBadge} from "./QuestBadge.sol";

/// @title QuestRegistry
/// @notice An open list of quests. Anyone can register a quest; the first three
///         ("built-in") quests are fixed at deployment and can never change.
/// @dev No owner, no admin, no upgrades. The registry never relies on third-party
///      quests for anything that moves value or mints: it only reads them.
contract QuestRegistry is ReentrancyGuard {
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

    /// @notice The soulbound badge, created by this registry. Only this registry can mint it.
    QuestBadge public immutable badge;

    QuestInfo[] private _quests;
    mapping(address quest => bool) public isRegistered;

    event QuestRegistered(uint256 indexed id, address indexed quest, address indexed registrant, string name);

    error InvalidQuestAddress();
    error AlreadyRegistered();
    error NameTooLong();
    error DescriptionTooLong();
    error UnknownQuest();
    error QuestNotComplete(uint256 id);
    error AlreadyClaimed();

    /// @param builtIn The three built-in quests, in order: join, deposit, withdraw.
    /// @param names Their display names.
    /// @param descriptions Their short descriptions.
    constructor(IQuest[BUILT_IN_COUNT] memory builtIn, string[BUILT_IN_COUNT] memory names, string[BUILT_IN_COUNT] memory descriptions) {
        badge = new QuestBadge();
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
    /// @dev A broken or hostile quest (reverts, burns gas, returns nothing or junk) counts as "not complete"
    ///      and never makes this call revert. See `_safeCheck`.
    function isComplete(uint256 id, address user) external view returns (bool) {
        if (id >= _quests.length) revert UnknownQuest();
        return _safeCheck(_quests[id].quest, user);
    }

    /// @notice Has `user` completed each of the three built-in quests? (join, deposit, withdraw)
    /// @dev Built-in quests are fixed at deployment and trusted, so they are called directly.
    function builtInProgress(address user) public view returns (bool[BUILT_IN_COUNT] memory done) {
        for (uint256 i = 0; i < BUILT_IN_COUNT; i++) {
            done[i] = IQuest(_quests[i].quest).check(user);
        }
    }

    /// @notice Claim your soulbound badge once all three built-in quests are complete.
    /// @dev Third-party quests are never called here, so they can't block or fake a claim.
    ///      Level is the number of built-in quests completed, which is always 3 at claim time.
    function claimBadge() external nonReentrant {
        if (badge.hasBadge(msg.sender)) revert AlreadyClaimed();
        for (uint256 i = 0; i < BUILT_IN_COUNT; i++) {
            if (!IQuest(_quests[i].quest).check(msg.sender)) revert QuestNotComplete(i);
        }
        badge.mint(msg.sender, uint8(BUILT_IN_COUNT));
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

    /// @dev Reads a third-party quest without trusting it. Only a call that succeeds and returns
    ///      exactly `true` (a full 32-byte word equal to 1) counts. Everything else is "not complete":
    ///      reverts, running out of gas, empty or short return data, values other than 1, and
    ///      oversized return data (only the first 32 bytes are ever copied, so a "return bomb" is harmless).
    function _safeCheck(address quest, address user) private view returns (bool ok) {
        bytes memory data = abi.encodeCall(IQuest.check, (user));
        uint256 gasLimit = CHECK_GAS_LIMIT;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let success := staticcall(gasLimit, quest, add(data, 0x20), mload(data), ptr, 0x20)
            ok := and(and(success, iszero(lt(returndatasize(), 0x20))), eq(mload(ptr), 1))
        }
    }
}
