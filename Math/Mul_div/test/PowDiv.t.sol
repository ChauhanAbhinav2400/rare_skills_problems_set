// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PowDiv} from "../src/PowDiv.sol";

contract PowDivTest is Test {
    PowDiv public c;

    function setUp() public {
        c = new PowDiv();
    }

    function test_101() public {
        assertEq(c.powDiv(0, 0, 1), 1);
    }

    function test_011() public {
        assertEq(c.powDiv(0, 1, 1), 0);
    }

    function test_001() public {
        assertEq(c.powDiv(0, 0, 1), 1);
    }

    function test_max2max() public {
        assertEq(c.powDiv(type(uint256).max, 2, type(uint256).max), type(uint256).max);
    }

    function test_3_255_max() public {
        assertEq(c.powDiv(3, 255, type(uint256).max), 400166808437280314332915720172965931925887476);
    }

    function test_4_255_2_255() public {
        assertEq(c.powDiv(4, 254, 2**254), 28948022309329048855892746252171976963317496166410141009864396001978282409984);
    }

}
