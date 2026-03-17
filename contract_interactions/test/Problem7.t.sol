//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {GetEther , HasEther } from "../src/Problem7.sol";

contract Problem7Test is Test {
GetEther getEther;
HasEther hasEther;

function setUp() public {
    
}

function  test_getEther() public {
    vm.deal(address(this) , 1 ether);
    getEther = new GetEther();
    hasEther = new HasEther{value:1 ether}();

    getEther.getEther(hasEther);
    assertEq(address(getEther).balance , 1 ether);
}

}