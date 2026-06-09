// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

contract OptimizedDistribute {
    address payable immutable contributor0;
    address payable immutable contributor1;
    address payable immutable contributor2;
    address payable immutable contributor3;

    uint256 public immutable unlockTime;

    constructor(address[4] memory _contributors) payable {
        contributor0 = payable(_contributors[0]);
        contributor1 = payable(_contributors[1]);
        contributor2 = payable(_contributors[2]);
        contributor3 = payable(_contributors[3]);
        unlockTime = block.timestamp + 1 weeks;
    }

    function distribute() external {
        require(block.timestamp > unlockTime, 'cannot distribute yet');

        uint256 amount = address(this).balance >> 2;
        address c0 = contributor0;
        address c1 = contributor1;
        address c2 = contributor2;
        address c3 = contributor3;
        assembly {
            pop(call(gas(), c0, amount, 0, 0, 0, 0))
            pop(call(gas(), c1, amount, 0, 0, 0, 0))
            pop(call(gas(), c2, amount, 0, 0, 0, 0))
            pop(call(gas(), c3, amount, 0, 0, 0, 0))
        }
    }
}
