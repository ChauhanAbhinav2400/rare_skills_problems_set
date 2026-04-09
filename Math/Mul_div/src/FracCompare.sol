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
     require(d1 != 0 && d2 != 0, "denominator cannot be zero");
    bool flipped = false ;
     while (true){
        uint256 q1 = n1 / d1;
        uint256 q2 = n2 / d2;
        uint256 r1 = n1 % d1;
        uint256 r2 = n2 % d2;

        if(q1 != q2){
            bool result =  q1 > q2;
            return flipped ? !result :result; 

        }
        if (r1 == 0 || r2 == 0) {
            bool  result =  r2 != 0; 
            return flipped ? !result : result;
        }
        n1 = d1;
        d1 = r1;
        n2 = d2;
        d2 = r2;
      flipped = !flipped ;
     }
     

    }
}
