//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;


contract ConvertToNegative{
error ToBig();

function convertToNegative (uint256 x) pure external returns(int256){
    if(x <= uint256(type(int256).max)){
      return -int256(x);
    }else{
      revert  ToBig();
    }
    
} 
}