// SPDX-License-Identifier : MIT 
pragma solidity ^0.8.20;
import {Test} from  "forge-std/Test.sol";
import {ERC20} from "../src/ERC20_practice2.sol";

contract TestERC20Practice is Test  { 

ERC20 token;
address user1 = makeAddr("user1");
address user2 = makeAddr("user2");

function setUp() public {
    token = new ERC20("TestToken", "TTK" , 100000);
}

function test_IntialBalance() public {
    uint256 ownerBalance = token.balanceOf(address(this));
    assertEq(ownerBalance , 100000 * 10 ** uint256(token.decimals()));
}

function test_nameAndSymbol() public {
    assertEq(token.name(), "TestToken");
    assertEq(token.symbol() , "TTK");
}

function test_Transfer() public {
    vm.prank(address(this));
    token.mint(user1 , 5000 * 10 ** uint256(token.decimals()));
    uint256 senderBalanceBefore = token.balanceOf(user1);
    uint256 receiverBalanceBefore = token.balanceOf(user2);
    
    vm.startPrank(user1);
    token.transfer(user2 , 1000 * 10 ** uint256(token.decimals()));
    vm.stopPrank();
    uint256 senderBalanceAfter = token.balanceOf(user1);
    uint256 receiverBalanceAfter = token.balanceOf(user2);

    assertEq(senderBalanceBefore - senderBalanceAfter , 1000 *10 ** uint256(token.decimals()));
    assertEq(receiverBalanceBefore + 1000 * 10 ** uint256(token.decimals()) , receiverBalanceAfter);

}

function test_TransferFrom() public {
  vm.prank(address(this));
  token.mint(user1 , 5000 * 10 ** uint256(token.decimals()));
  vm.startPrank(user1);
    token.approve(address(this), 2000 * 10 ** uint256(token.decimals()));
    vm.stopPrank();

    uint256 senderBalanceBefore = token.balanceOf(user1);
    uint256 receiverBalanceBefore = token.balanceOf(user2);
    uint256 allowanceBefore = token.allowance(user1,address(this));

    vm.prank(address(this));
    token.transferFrom(user1 , user2 , 1500 * 10 ** uint256(token.decimals()));

    uint256 senderBalanceAfter = token.balanceOf(user1);
    uint256 receiverBalanceAfter = token.balanceOf(user2);
    uint256 allowanceAfter = token.allowance(user1,address(this));

    assertEq(senderBalanceBefore -1500 * 10 ** uint256(token.decimals()) , senderBalanceAfter);
    assertEq(receiverBalanceBefore + 1500 * 10 ** uint256(token.decimals()) , receiverBalanceAfter);
    assertEq(allowanceBefore -1500 * 10 ** uint256(token.decimals()), allowanceAfter);


}

function test_approve() public {
   
  vm.prank(address(this));
  token.mint(user1 , 5000 * 10 ** uint256(token.decimals()));
    uint256 allowaceBefore = token.allowance(user1, user2);
    vm.startPrank(user1);
     token.approve(user2 , 3000 * 10 ** uint256(token.decimals()));
    vm.stopPrank();
     uint256 allowanceAfter = token.allowance(user1 , user2);

     assertEq(allowanceAfter , allowaceBefore + 3000 * 10 ** uint256(token.decimals()));
}

function test_mint() public {
    
    uint256 totalSupplyBefore = token.totalSupply();
    uint256 balanceBefore = token.balanceOf(user1);
    vm.prank(address(this));
    token.mint(user1, 4000 * 10 ** uint256(token.decimals()));
    uint256 totalSupplyAfter = token.totalSupply();
    uint256 balanceAfter = token.balanceOf(user1);

    assertEq(totalSupplyAfter , totalSupplyBefore + 4000 *10 ** uint256(token.decimals()));
    assertEq(balanceBefore + 4000 *10 ** uint256(token.decimals()) , balanceAfter);
}

function test_burn() public {
    token.mint(user1 , 5000 * 10 ** uint256(token.decimals()));
      uint256 totalSupplyBefore = token.totalSupply();
    uint256 balanceBefore = token.balanceOf(user1);
    vm.prank(address(this));
    token.burn(user1, 2000 * 10 ** uint256(token.decimals()));
    uint256 totalSupplyAfter = token.totalSupply();
    uint256 balanceAfter = token.balanceOf(user1);
    assertEq(totalSupplyAfter , totalSupplyBefore - 2000 *10 ** uint256(token.decimals()));
    assertEq(balanceBefore - 2000 *10 ** uint256(token.decimals()) , balanceAfter);

}

}