// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

contract OptimizedDistribute {
    address[4] public contributors;
    uint256 public immutable unlockTime;

    constructor(address[4] memory _contributors) payable {
        contributors = _contributors;
        unlockTime = block.timestamp + 1 weeks;
    }

    function distribute() external {
        require(block.timestamp > unlockTime, 'cannot distribute yet');

        uint256 amount = address(this).balance >> 2;
        payable(contributors[0]).transfer(amount);
        payable(contributors[1]).transfer(amount);
        payable(contributors[2]).transfer(amount);
        payable(contributors[3]).transfer(amount);
    }
}
