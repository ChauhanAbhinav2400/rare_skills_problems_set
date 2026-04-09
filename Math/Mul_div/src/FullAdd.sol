// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract FullAdd {

    function fullAdd(uint256 x, uint256 y) public pure returns (uint256 sum, bool overflow) {
        // TODO
        unchecked {
            sum = x + y;
            overflow = sum < x;
        }
    }
}
