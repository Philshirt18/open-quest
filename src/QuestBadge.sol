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

    /// @notice The badge artwork as an SVG, drawn on-chain from the level and the owner's address.
    /// @dev An arc with one node per quest (filled when reached), the level in the middle, and the owner's
    ///      short address at the bottom. Nothing is hosted anywhere; wallets and explorers render this directly.
    function svgOf(uint256 tokenId) public view returns (string memory) {
        address owner = _requireOwned(tokenId);
        uint8 level = levelOf[tokenId];
        return string.concat(_frame(level), _arc(level), _labels(level, owner), "</svg>");
    }

    /// @dev Background, glow, border and title.
    function _frame(uint8 level) private pure returns (string memory) {
        return string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 400 400' role='img' aria-label='Open Quest badge, level ",
            Strings.toString(level), "'>",
            _defs(),
            "<rect width='400' height='400' rx='44' fill='url(#bg)'/>",
            "<rect width='400' height='400' rx='44' fill='url(#glow)'/>",
            "<rect x='10' y='10' width='380' height='380' rx='36' fill='none' stroke='#4D8EE9' stroke-opacity='0.35' stroke-width='2'/>",
            "<text x='200' y='64' text-anchor='middle' font-family='Helvetica,Arial,sans-serif' font-size='20' letter-spacing='7' fill='#9CC3F5'>OPEN QUEST</text>"
        );
    }

    /// @dev The arc and one node per quest.
    function _arc(uint8 level) private pure returns (string memory) {
        return string.concat(
            "<path d='M70 252 A130 130 0 0 1 330 252' fill='none' stroke='url(#arc)' stroke-width='8' stroke-linecap='round'/>",
            _node(70, 252, level >= 1), _node(200, 122, level >= 2), _node(330, 252, level >= 3)
        );
    }

    /// @dev Level, quest names, "built on Arc" and the owner's short address.
    function _labels(uint8 level, address owner) private pure returns (string memory) {
        return string.concat(
            "<text x='200' y='178' text-anchor='middle' font-family='Helvetica,Arial,sans-serif' font-size='16' letter-spacing='6' fill='#9CC3F5'>LEVEL</text>",
            "<text x='200' y='246' text-anchor='middle' font-family='Helvetica,Arial,sans-serif' font-size='84' font-weight='300' fill='#FFFFFF'>",
            Strings.toString(level), "</text>",
            "<text x='200' y='306' text-anchor='middle' font-family='Helvetica,Arial,sans-serif' font-size='15' fill='#9CC3F5'>Join  \u00B7  Deposit  \u00B7  Withdraw</text>",
            "<text x='200' y='338' text-anchor='middle' font-family='Helvetica,Arial,sans-serif' font-size='15' fill='#5FBFFF'>built on Arc</text>",
            "<text x='200' y='366' text-anchor='middle' font-family='Menlo,Consolas,monospace' font-size='14' fill='#6B86B8'>",
            _short(owner), "</text>"
        );
    }

    function _defs() private pure returns (string memory) {
        return string.concat(
            "<defs>",
            "<linearGradient id='bg' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#0B1020'/><stop offset='1' stop-color='#1B2E5C'/></linearGradient>",
            "<linearGradient id='arc' x1='0' y1='0' x2='1' y2='0'><stop offset='0' stop-color='#4D8EE9'/><stop offset='1' stop-color='#5FBFFF'/></linearGradient>",
            "<radialGradient id='glow' cx='0.5' cy='0.4' r='0.55'><stop offset='0' stop-color='#5FBFFF' stop-opacity='0.30'/><stop offset='1' stop-color='#5FBFFF' stop-opacity='0'/></radialGradient>",
            "</defs>"
        );
    }

    /// @dev One quest node on the arc: a white disc with a tick when reached, a dark empty disc when not.
    function _node(uint256 x, uint256 y, bool on) private pure returns (string memory) {
        string memory sx = Strings.toString(x);
        string memory sy = Strings.toString(y);
        if (!on) {
            return string.concat("<circle class='off' cx='", sx, "' cy='", sy, "' r='20' fill='#0B1020' stroke='#2A3E6E' stroke-width='6'/>");
        }
        return string.concat(
            "<circle class='on' cx='", sx, "' cy='", sy, "' r='20' fill='#FFFFFF' stroke='#5FBFFF' stroke-width='6'/>",
            "<path d='M", Strings.toString(x - 8), " ", Strings.toString(y), " l6 6 l11 -12' fill='none' stroke='#2F6FCF' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>"
        );
    }

    /// @dev "0x28b8\u202627b9": the first 6 and last 4 characters of the address.
    function _short(address a) private pure returns (string memory) {
        bytes memory full = bytes(Strings.toHexString(uint256(uint160(a)), 20)); // "0x" + 40 hex chars
        bytes memory head = new bytes(6);
        bytes memory tail = new bytes(4);
        for (uint256 i = 0; i < 6; i++) head[i] = full[i];
        for (uint256 i = 0; i < 4; i++) tail[i] = full[38 + i];
        return string.concat(string(head), unicode"\u2026", string(tail));
    }

    /// @notice On-chain metadata and the artwork, so wallets can show the badge without any hosting.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory level = Strings.toString(levelOf[tokenId]);
        string memory json = string.concat(
            '{"name":"Open Quest Badge - Level ', level,
            '","description":"Soulbound badge for finishing the Open Quest onboarding quests on Arc: join, deposit and withdraw. It cannot be transferred.",',
            '"attributes":[{"trait_type":"Level","value":', level, '},{"trait_type":"Network","value":"Arc"}],',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svgOf(tokenId))), '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }
}
