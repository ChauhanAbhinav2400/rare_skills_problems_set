// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract Multiplication {

    function main(uint8 rewards  , uint8 numDays) public pure returns(uint256 totalawards){
        return rewards * numDays;
    }
 }