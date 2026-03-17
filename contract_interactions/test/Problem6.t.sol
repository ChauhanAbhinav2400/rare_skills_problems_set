//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Target, Forwarder ,YourContract} from "../src/Problem6.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken" , "TT") {
        _mint(msg.sender , 1000 * 10 ** decimals());
    }
}

contract Problem6Test is Test {

Target target;
Forwarder forwarder;
YourContract yourContract;
TestToken testToken;

function setUp() public {
yourContract = new YourContract();
testToken = new TestToken();    
forwarder = new Forwarder();
target = new Target(address(testToken) , address(forwarder));

}

function test_main() public {
testToken.transfer(address(target), 10 * 10 ** 18);
uint256 beforeBalance = testToken.balanceOf(address(yourContract));
yourContract.main(address(target) , address(forwarder));
uint256 afterBalance = testToken.balanceOf(address(yourContract));

assertEq(beforeBalance , 0);
assertEq(afterBalance , 100 );

}



}