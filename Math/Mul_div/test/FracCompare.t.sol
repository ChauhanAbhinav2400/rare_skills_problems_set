// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FracCompare} from "../src/FracCompare.sol";

contract CounterTest is Test {
    FracCompare public c;

    function setUp() public {
        c = new FracCompare();
    }

    function test_max_max() public view {
        assertEq(c.fracCompare(type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max), false);
    }

    function test_max_maxMin1() public view {
        assertEq(c.fracCompare(type(uint256).max, type(uint256).max, type(uint256).max - 1, type(uint256).max), true);
    }

    function test_massive_difference_true() public view {
        assertEq(c.fracCompare(type(uint256).max, 1, 1, type(uint256).max), true);
    }

    function test_massive_difference_false() public view {
        assertEq(c.fracCompare(1, type(uint256).max, type(uint256).max, 1), false);
    }

    function test_both_round_to_zero_true() public view {
        assertEq(c.fracCompare(1,2,1,3), true);
    }

    function test_both_round_to_zero_false() public view {
        assertEq(c.fracCompare(1,3,1,2), false);
    }

    function test_11_01() public view {
        assertEq(c.fracCompare(1,1,0,1), true);
    }
}
