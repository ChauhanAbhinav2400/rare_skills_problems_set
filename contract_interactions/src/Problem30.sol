// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract StringIndex {
   function getStringAtIndex(string memory str , uint256 index) public pure returns(string memory){
    bytes memory b = bytes(str);
    require(index < b.length , "Index Out of Bounds");
    bytes memory out = new bytes(1);
    out[0] = b[index];
    return string(out);
    }
} 