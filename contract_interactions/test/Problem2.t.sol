// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Badbank, Rob} from "../src/Problem2.sol";

contract Problem2Test is Test {
    Badbank badbank ;
    Rob rob; 

address victimWallet = makeAddr("victim");
address robberWallet = makeAddr("robber");
function setUp() public {
    badbank = new Badbank();
    rob = new Rob(address(badbank));

vm.deal(victimWallet , 10 ether);
vm.deal(robberWallet , 1 ether);

vm.prank(victimWallet);
badbank.deposit{value : 10 ether}();
    
}


function test_robBank() public {
    vm.prank(robberWallet);
    rob.deposit{value:1 ether}();
    rob.rob();
    assertEq(address(rob).balance , 5 ether );
    assertEq(address(badbank).balance , 6 ether);
}

}