// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract PolyDiv {

    using Math for uint256;

    /* 
     * @dev return (x^5 + x) / (x^2 + 4x + 3)
     */
    function polyDiv(uint256 x) public pure returns (uint256) {
        // TODO
    }
}
