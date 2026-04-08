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
    }
}
