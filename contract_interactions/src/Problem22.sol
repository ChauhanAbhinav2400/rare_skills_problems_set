// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract NodelegateCall {
    address immutable public SELF;

    constructor() {
    SELF = address(this);
    }

    function meaningOfLifeAndEverything() view external returns(uint256 fourtyTwo){
    require(address(this) == SELF , "NO DELEGATECALL ALLOWED");
    fourtyTwo = 42;
    }
}