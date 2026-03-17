//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ConvertToNegative} from "../src/Problem4.sol";

contract ConvertToNegativeTest is Test {

ConvertToNegative c ;

function setUp() public {
    c = new ConvertToNegative();
}

function test_convertToNegative_case0(uint256 x) public {
    assertEq(c.convertToNegative(1) , -1);
    assertEq(c.convertToNegative(0) , 0);
    assertEq(c.convertToNegative(12345678900987654321) , -12345678900987654321);
}

function test_convertToNegative_revert() public {
    vm.expectRevert(ConvertToNegative.ToBig.selector);
    c.convertToNegative(57896044618658097711785492504343953926634992332820282019728792003956564819969);
}
}
