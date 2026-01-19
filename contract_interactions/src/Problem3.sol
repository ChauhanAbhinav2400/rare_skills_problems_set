//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

contract Bytes {

    function main(uint8 z) external pure returns(bytes memory ){
    bytes memory result = new bytes(z);
    for(uint8 i = 0 ; i < z ; i++ ){
    result[i] = bytes1(i);
    }
    return result;
    } 
}