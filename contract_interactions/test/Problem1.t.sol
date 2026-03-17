//SPDX-License-Identifier:MIT 
pragma solidity ^0.8.26;

import {Test} from "../lib/forge-std/src/Test.sol";
import {AccountMaker,Account as Account2} from "../src/Problem1.sol";

contract Problem1Test is Test {
AccountMaker accountMaker;


function setUp() public {
accountMaker = new AccountMaker();
}

function predictAddress( address _owner) view public returns(address){
   bytes32 ownerB32 = bytes32(uint256(uint160(_owner)));
    bytes32 hash = keccak256(abi.encodePacked(
        bytes1(0xff),
        address(accountMaker),
          ownerB32,
          keccak256(abi.encodePacked(
          type(Account2).creationCode,
          abi.encode(_owner)
          ))
    ));
    address result = address(uint160(uint(hash)));
    return result;
}

function test_accountMaker_case0 () public {
vm.deal(address(accountMaker),100 ether);
address owner = makeAddr("owner");
address account = accountMaker.makeAccount{value:1 ether}(owner);
assertEq(account , predictAddress(owner));
assertEq(account.balance, 1 ether);
}

function test_accountMaker_case1 () public {
    vm.deal(address(accountMaker) , 100 ether);
    address owner = makeAddr("owner");
    address account = accountMaker.makeAccount{value : 1 ether}(owner);
    assertEq(account , predictAddress(owner));
    assertEq(account.balance , 1 ether);    
}

}