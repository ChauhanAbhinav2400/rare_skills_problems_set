//SPDX-License-Identifier :    MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Bytes} from "../src/Problem3.sol";

contract BytesTest is Test {
Bytes c;

function setUp() public {
     c = new Bytes();
}

function test_main(uint8 z) public {
    bytes memory result = c.main(z);
    for(uint8 i = 0 ; i < z ; i++){
        assertEq(result[i], bytes1(i));
    }
}


}