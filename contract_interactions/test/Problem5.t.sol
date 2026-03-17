//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;  

import {Test} from "forge-std/Test.sol";
import {Div} from "../src/Problem5.sol";

contract Problem5Test is Test {

Div div;

function setUp() public {
    div = new Div();
}

function test_div_revert_On_denominator_is_zero() public {
    vm.expectRevert(Div.DenominatorIsZero.selector);
    div.div(10,0);
}

function test_result_when_x_divides_y_exactly() public {
     uint256 result = div.div(10,2);
    assertEq(result, 5);

}

function test_result_when_x_divides_y_not_exactly() public {
   assertEq(div.div(10,3),4);



}
}