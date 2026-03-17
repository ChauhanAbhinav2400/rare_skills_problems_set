//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

contract IsNBitSet {

function main (bytes32 x , uint256 n ) public  pure returns(bool){
    return (x & bytes32(uint256(1 << n))) != 0  ;
    }

}