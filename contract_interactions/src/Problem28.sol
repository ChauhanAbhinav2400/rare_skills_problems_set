// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract StringCompare {
    function compare(string memory a, string memory b) public pure returns (bool) {
       return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}