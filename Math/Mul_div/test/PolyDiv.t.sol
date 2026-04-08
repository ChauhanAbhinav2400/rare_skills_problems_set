// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PolyDiv} from "../src/PolyDiv.sol";

contract PolyDivTest is Test {

    PolyDiv c;

    function setUp() public {
        c = new PolyDiv();
    }

    function test_round_down() public {
        assertEq(c.polyDiv(1), 0);
    }

    function test_simple_case() public {
        assertEq(c.polyDiv(2), 2);
    }

    function test_large_case() public {
        assertEq(c.polyDiv(2**63 + 2**62), 2648152294616255946477588337343622726680444091130454212568);
    }
}
