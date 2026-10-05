// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IQuest} from "../src/IQuest.sol";
import {QuestRegistry} from "../src/QuestRegistry.sol";

/// @dev Returns nothing at all (empty return data).
contract EmptyReturnQuest {
    fallback() external {}
}

/// @dev Returns a value that is not a valid bool (2).
contract BadBoolQuest {
    fallback() external {
        assembly {
            mstore(0, 2)
            return(0, 32)
        }
    }
}

/// @dev Returns only 1 byte.
contract ShortReturnQuest {
    fallback() external {
        assembly {
            mstore(0, 0x01)
            return(31, 1)
        }
    }
}

/// @dev Returns a huge blob of data (a "return bomb").
contract ReturnBombQuest {
    fallback() external {
        assembly {
            return(0, 100000)
        }
    }
}

contract OkQuest is IQuest {
    function check(address) external pure returns (bool) {
        return true;
    }
}

contract HostileQuestTest is Test {
    QuestRegistry registry;

    function setUp() public {
        IQuest[3] memory b = [IQuest(new OkQuest()), IQuest(new OkQuest()), IQuest(new OkQuest())];
        string[3] memory n = ["a", "b", "c"];
        registry = new QuestRegistry(b, n, n);
    }

    function _id(address q) internal returns (uint256) {
        return registry.registerQuest(q, "x", "y");
    }

    function test_emptyReturnCountsAsNotComplete() public {
        assertFalse(registry.isComplete(_id(address(new EmptyReturnQuest())), address(1)));
    }

    function test_invalidBoolCountsAsNotComplete() public {
        assertFalse(registry.isComplete(_id(address(new BadBoolQuest())), address(1)));
    }

    function test_shortReturnCountsAsNotComplete() public {
        assertFalse(registry.isComplete(_id(address(new ShortReturnQuest())), address(1)));
    }

    function test_returnBombIsHarmless() public {
        uint256 id = _id(address(new ReturnBombQuest()));
        uint256 before = gasleft();
        assertFalse(registry.isComplete(id, address(1)));
        assertLt(before - gasleft(), 400_000);
    }
}
