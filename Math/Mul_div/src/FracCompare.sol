// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract FracCompare {

    using Math for uint256;

    /*
     * @notice returns true if n1/d1 > n2/d2
     * @dev never reverts unless d1 = 0 or d2 = 0. Works properly for all other inputs.
     * @param n1 uint256 numerator of the first fraction
     * @param d1 uint256 numerator of the first fraction
     * @param n2 uint256 numerator of the second fraction
     * @param d2 uint256 numerator of the second fraction
     * @return bool. True if the first fraction is strictly greater than the second
     */
    function fracCompare(uint256 n1, uint256 d1, uint256 n2, uint256 d2) public pure returns (bool) {
        // TODO
    }
}
