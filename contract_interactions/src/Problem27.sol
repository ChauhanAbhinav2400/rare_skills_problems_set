// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

library  StorageSetLib {

struct S {
    uint256 x;
}

function increment(S storage self) internal  {
    self.x += 1;
} 

}

contract StorageSet {
 StorageSetLib.S public s;
 using StorageSetLib for StorageSetLib.S;   

function main() public  {
    s.increment();
}


}