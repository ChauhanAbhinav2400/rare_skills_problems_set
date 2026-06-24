// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

contract Require {
    // Do not modify these variables
    uint256 constant COOLDOWN = 1 minutes;
    uint256 public lastPurchaseTime;

    // Optimize this function
    error CannotPurchase();

    function purchaseToken() external payable {
        uint256 lastTime = lastPurchaseTime;

        if (msg.value != 0.1 ether || block.timestamp <= lastTime + COOLDOWN)
            revert CannotPurchase();

        lastPurchaseTime = block.timestamp;
    }
}
