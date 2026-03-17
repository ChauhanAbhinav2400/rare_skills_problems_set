// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BasicBankERC20 {
using SafeERC20 for IERC20;

event Deposit(address indexed user ,address indexed token,  uint256 amount);
event Withdraw(address indexed user ,address indexed token,  uint256 amount);

error FeeOnTransferNotSupported();
error InsufficientBalance();

mapping(address => mapping(address => uint256)) public userTokenBalance;

function deposit(address token , uint256 amount) external {
require(amount > 0 , "Amount must be greater than 0");
require(token !=  address(0), "Invalid token address");
require(token != address(this), "Cannot deposit bank token itself");
require(token.code.length > 0 , "Token address must be a contract");
uint256 beforeBalance = IERC20(token).balanceOf(address(this));
IERC20(token).safeTransferFrom(msg.sender , address(this), amount);  
uint256 afterBalance = IERC20(token).balanceOf(address(this));
if(afterBalance - beforeBalance < amount){
    revert FeeOnTransferNotSupported();
}
userTokenBalance[msg.sender][token] += amount;
emit Deposit(msg.sender , token , amount);
}


function withdraw( address token , uint256 amount) external {
require(amount > 0 , "Amount must be greater than 0");
require(token !=  address(0), "Invalid token address");
require(token != address(this), "Cannot deposit bank token itself");
require(token.code.length > 0 , "Token address must be a contract");

uint256 userBalance = userTokenBalance[msg.sender][token];
if(userBalance < amount){
    revert InsufficientBalance();
}
userTokenBalance[msg.sender][token] = userBalance - amount;
IERC20(token).safeTransfer(msg.sender,amount);
emit Withdraw(msg.sender , token , amount);
}


}