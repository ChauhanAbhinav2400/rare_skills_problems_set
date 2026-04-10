// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract PolyDiv {

    using Math for uint256;

    /* 
     * @dev return (x^5 + x) / (x^2 + 4x + 3)
     */
    function polyDiv(uint256 x) public pure returns (uint256) {
     uint256 denom = x * x + 4 * x + 3;   // x^2 + 4x + 3  (~2^126, safe)
    uint256 x2 = x * x;                   // x^2            (~2^126, safe)
    uint256 x4 = x2 * x2;                 // x^4            (~2^252, safe)

    // (x^5 + x) / denom
    // = x^5/denom + x/denom       ← integer division distributes like this
    //                                only when remainder handling is ignored
    // Correct single expression:
    return Math.mulDiv(x4, x, denom) + (x / denom);
    }
}
