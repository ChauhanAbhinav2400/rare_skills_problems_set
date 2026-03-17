//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;


contract Div {

error DenominatorIsZero();

function div(uint256 x , uint256 y) pure external returns(uint256) {
    // if y divides x exactly  then return x/y
    // if x/y return fraction add 1 to result 
    // if y == 0 revert 
    if( y == 0 ) revert DenominatorIsZero();

    uint256 result = x/y;
    if(x%y == 0 ) {
        return result ;
    }else{
        return result + 1;
    }
}

}