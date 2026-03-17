//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from  "forge-std/Test.sol";
import {ERC20} from "../src/ERC20_practice10.sol";

contract ERC20Test is Test {
ERC20 public token;
address bob = makeAddr("bob");
address alice = makeAddr("alice");


event Transfer(address indexed from , address indexed to , uint256 value);
event Approval(address indexed owner , address indexed spender , uint256 value);

function setUp() public {
    token = new ERC20("TestToken","TT",1000);
}

function test_name_symbol() public {
    assertEq(token.name(),"TestToken");
    assertEq(token.symbol(),"TT");
}

function test_constructor() public {
    assertEq(token.totalSupply(),1000 * 10 ** token.decimals());
    assertEq(token.balanceOf(address(this)), 1000 * 10 ** token.decimals());
    assertEq(token.owner() , address(this));
}

function test_modifier_validAddress() public {
    vm.expectRevert("ERC20: address is zero");
    token.transfer(address(0),100);
}

function test_transfer_only() public {
token.transfer(bob,100 * 10 ** token.decimals());
vm.startPrank(bob);
uint256 bobBalanceBefore = token.balanceOf(bob);
uint256 aliceBalanceBefore = token.balanceOf(alice);
token.transfer(alice, 50 * 10 ** token.decimals());
uint256 bobBalanceAfter = token.balanceOf(bob);
uint256 aliceBalanceAfter = token.balanceOf(alice);
vm.stopPrank();
assertEq(bobBalanceAfter , bobBalanceBefore - 50 * 10 ** token.decimals());
assertEq(aliceBalanceAfter , aliceBalanceBefore + 50 * 10 ** token.decimals());

}

function test_transfer_insufficientBalance() public {
    vm.startPrank(bob);
    uint256 decimals = token.decimals();
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    token.transfer(alice, 100 * 10 ** decimals);
    vm.stopPrank();
}

function test_approve() public {
    token.approve(bob,100 * 10 ** token.decimals());
    assertEq(token.allowance(address(this),bob) , 100 * 10 ** token.decimals());
}

function  test_transferFrom() public {
    token.approve(bob , 100 * 10 ** token.decimals());
    vm.startPrank(bob);
    uint256 aliceBalanceBefore = token.balanceOf(alice);
    uint256 ownerBalanceBefore = token.balanceOf(address(this));
    token.transferFrom(address(this),alice , 50*10** token.decimals());
    uint256 aliceBalanceAfter = token.balanceOf(alice);
    uint256 ownerBalanceAfter = token.balanceOf(address(this));
    vm.stopPrank();
    assertEq(aliceBalanceAfter, aliceBalanceBefore + 50 * 10 ** token.decimals());
    assertEq(ownerBalanceAfter, ownerBalanceBefore - 50 * 10 ** token.decimals());
}

function test_transferFrom_insufficientAllowance() public {
    vm.prank(bob);
    uint256 decimals = token.decimals();
    vm.expectRevert("ERC20: insufficient allowance");
    token.transferFrom(address(this),alice,50*10 ** decimals);
}


function test_transferFrom_insufficientBalance() public {
    token.approve(bob , type(uint256).max);
     uint256 decimals = token.decimals();
    vm.startPrank(bob);
    vm.expectRevert("ERC20: transfer amount exceeds balance");  
    token.transferFrom(address(this),alice,2000 * 10 ** decimals);
    vm.stopPrank();
}
 
 function test_mint() public {
    uint256 aliceBalanceBefore = token.balanceOf(alice);
    uint256 totalSupplyBefore = token.totalSupply();
    token.mint(alice, 100 * 10 ** token.decimals());
    uint256 aliceBalanceAfter = token.balanceOf(alice);
    uint256 totalSupplyAfter = token.totalSupply();
    assertEq(aliceBalanceAfter , aliceBalanceBefore + 100 * 10 ** token.decimals());
    assertEq(totalSupplyAfter , totalSupplyBefore + 100 * 10 ** token.decimals());
   
 }

 function test_burn() public {
    uint256 aliceBalanceBefore = token.balanceOf(alice);
    uint256 totalSupplyBefore = token.totalSupply();
  token.burn(address(this), 100 * 10 ** token.decimals());
  uint256 aliceBalanceAfter = token.balanceOf(alice);
  uint256 totalSupplyAfter = token.totalSupply();
  assertEq(aliceBalanceAfter , aliceBalanceBefore);
  assertEq(totalSupplyAfter , totalSupplyBefore - 100 * 10 ** token.decimals());
 }

 function test_burn_insufficientBalance() public {
  uint256 decimals = token.decimals();
   vm.expectRevert("ERC20: burn amount exceeds balance");
   token.burn(address(this), 2000 * 10 ** decimals);
}

function test_transfer_event( ) public {
    vm.expectEmit(true, true, false , false );
    emit Transfer(address(this), bob , 50 * 10 ** token.decimals());
    token.transfer(bob , 50 * 10 ** token.decimals());
}

function test_approval_event() public {
    vm.expectEmit(true , true, false , false);
    emit Approval(address(this), bob , 100 * 10 ** token.decimals());
    token. approve(bob , 100 * 10 ** token.decimals());
}


}