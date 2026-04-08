// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FullAdd} from "../src/FullAdd.sol";

contract FullAddTest is Test {
    FullAdd public c;

    function setUp() public {
        c = new FullAdd();
    }

    function test_00() public {
        (uint256 sum, bool overflow) = c.fullAdd(0, 0);
        assertEq(sum, 0);
        assertEq(overflow, false);
    }

    function test_max0() public {
        (uint256 sum, bool overflow) = c.fullAdd(type(uint256).max, 0);
        assertEq(sum, type(uint256).max);
        assertEq(overflow, false);
    }

    function test_0max() public {
        (uint256 sum, bool overflow) = c.fullAdd(0, type(uint256).max);
        assertEq(sum, type(uint256).max);
        assertEq(overflow, false);
    }

    function test_max1() public {
        (uint256 sum, bool overflow) = c.fullAdd(type(uint256).max, 1);
        assertEq(sum, 0);
        assertEq(overflow, true);
    }

    function test_maxmax() public {
        (uint256 sum, bool overflow) = c.fullAdd(type(uint256).max, type(uint256).max);
        assertEq(sum, type(uint256).max - 1);
        assertEq(overflow, true);
    }

}
