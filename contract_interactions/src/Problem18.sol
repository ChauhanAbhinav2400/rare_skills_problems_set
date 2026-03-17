// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;


contract MemoryArray {


function main(uint8 x) public pure returns(uint8[] memory result) {
result = new uint8[](x);
for(uint8 i = 0 ; i < x ; i++){
 result[i] = i; 
   }
   return result;
}
}