// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

contract RemoveElement {

    uint256[] public arr;

    function setArr(uint256[] memory _arr) public {
        arr = _arr;
    }

    function removeElement(uint256 index) public {
        require(index < arr.length, "Index out of bounds");

        uint256 lastIndex = arr.length - 1;

        // swap
        arr[index] = arr[lastIndex];

        // pop
        arr.pop();
    }
}
