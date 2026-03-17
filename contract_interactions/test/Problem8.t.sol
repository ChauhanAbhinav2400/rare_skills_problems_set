//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IsContract} from "../src/Problem8.sol";

contract IsContractTest is Test {

IsContract isContract;

function setUp() public {
    isContract = new IsContract();
}

function test_isContract() public {
   assertEq(isContract.iscontract(address(this)), true);
   assertEq(isContract.iscontract(address(0x123)), false);
}
}