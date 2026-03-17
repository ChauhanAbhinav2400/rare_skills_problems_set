// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract StringConcat {
    function concat(string memory a, string memory b) public pure returns (string memory) {
        return string(abi.encodePacked(a,b));
    }
}