// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title QuestBadge
/// @notice Soulbound (non-transferable) badge, one per wallet, with an on-chain level.
/// @dev Only the registry that deployed it can mint. The token id is the owner's address
///      as a number, so a wallet can never hold two badges. Implements ERC-5192 (minimal soulbound).
contract QuestBadge is ERC721 {
    /// @notice The registry that deployed this badge. The only address allowed to mint.
    address public immutable registry;

    mapping(uint256 tokenId => uint8) public levelOf;

    /// @dev ERC-5192: emitted once when a token is minted and locked.
    event Locked(uint256 tokenId);

    error NotRegistry();
    error Soulbound();

    constructor() ERC721("Open Quest Badge", "OQB") {
        registry = msg.sender;
    }

    function mint(address to, uint8 level) external {
        if (msg.sender != registry) revert NotRegistry();
        uint256 id = tokenIdOf(to);
        levelOf[id] = level;
        _mint(to, id); // no receiver callback, so nothing can re-enter
        emit Locked(id);
    }

    function tokenIdOf(address owner) public pure returns (uint256) {
        return uint256(uint160(owner));
    }

    function hasBadge(address owner) external view returns (bool) {
        return _ownerOf(tokenIdOf(owner)) != address(0);
    }

    /// @notice ERC-5192: badges are always locked.
    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return true;
    }

    /// @dev Blocks every transfer; only minting (from == address(0)) is allowed.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (_ownerOf(tokenId) != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId); // ERC-5192
    }

    /// @notice On-chain metadata and a small SVG, so wallets can show the badge without any hosting.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory level = Strings.toString(levelOf[tokenId]);
        string memory svg = string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200'>",
            "<rect width='200' height='200' rx='32' fill='#4D8EE9'/>",
            "<text x='100' y='92' font-family='sans-serif' font-size='20' fill='#fff' text-anchor='middle'>Open Quest</text>",
            "<text x='100' y='142' font-family='sans-serif' font-size='56' fill='#fff' text-anchor='middle'>L", level, "</text></svg>"
        );
        string memory json = string.concat(
            '{"name":"Open Quest Badge - Level ', level,
            '","description":"Soulbound badge for completing the Open Quest onboarding quests on Arc.",',
            '"attributes":[{"trait_type":"Level","value":', level, '}],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }
}
