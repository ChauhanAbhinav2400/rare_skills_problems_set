// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Average {

    /*
     * @dev returns the average of x and y rounded down. As long as
     * (x + y) / 2 fits in a uint256, it does not overflow even if the
     * numerator temporarily overflows
     */
    function average(uint256 x, uint256 y) public pure returns (uint256 z) {
        // TODO
        unchecked{
             z = (x & y) + ((x ^ y) / 2);
        }
        
    }
}
