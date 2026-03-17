
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract RationalFunction {

    function f(uint256 x) public pure returns (uint256) {
       require( x < type(uint256).max / 100  && x > 1 , "INAVLID NUMBER ");
       return  (x * 100) / (x - 1 ) ; 
    }
}
