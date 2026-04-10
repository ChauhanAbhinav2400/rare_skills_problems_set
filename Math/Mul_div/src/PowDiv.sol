// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract PowDiv {

    using Math for uint256;
    /*
     * @dev return n ** e / d. Revert if d == 0 or final result is > type(uint256).max
     */
    function powDiv(uint256 n, uint256 e, uint256 d) public pure returns (uint256) {
        // TODO
        require(d != 0, "denominator cannot be zero");

       if(e == 0){
        return 1/d;
       }
       if(n == 0 ) return 0;

       uint256 result = 1;
       uint256 base = n; 
       uint256 exp = e-1;

       while(exp > 0){
        if(exp % 2 == 1) {
            result = Math.mulDiv(result ,base , 1);
        }
        base = Math.mulDiv(base , base , 1);
        exp = exp / 2;
       }

       return Math.mulDiv(result , n , d);

    }
}
