// // SPDX-License-Identifier: (c) RareSkills

pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DecimalSwap {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable tokenA;
    IERC20Metadata public immutable tokenB;

    uint8 public immutable decimalsA;
    uint8 public immutable decimalsB;

    error ZeroOutput();
    error InsufficientLiquidity();
    error FeeOnTransferNotSupported();

    constructor(address tokenA_, address tokenB_) {
        tokenA = IERC20Metadata(tokenA_);
        tokenB = IERC20Metadata(tokenB_);
        decimalsA = tokenA.decimals();
        decimalsB = tokenB.decimals();
    }

    function swapAtoB(uint256 amountIn) external {
        uint256 balanceBefore = tokenA.balanceOf(address(this));
        tokenA.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 received = tokenA.balanceOf(address(this)) - balanceBefore;

        if (received != amountIn) revert FeeOnTransferNotSupported();

        uint256 amountOut = _convert(received, decimalsA, decimalsB);
        if (amountOut == 0) revert ZeroOutput();
        if (tokenB.balanceOf(address(this)) < amountOut) revert InsufficientLiquidity();

        tokenB.safeTransfer(msg.sender, amountOut);
    }

    function swapBtoA(uint256 amountIn) external {
        uint256 balanceBefore = tokenB.balanceOf(address(this));
        tokenB.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 received = tokenB.balanceOf(address(this)) - balanceBefore;

        if (received != amountIn) revert FeeOnTransferNotSupported();

        uint256 amountOut = _convert(received, decimalsB, decimalsA);
        if (amountOut == 0) revert ZeroOutput();
        if (tokenA.balanceOf(address(this)) < amountOut) revert InsufficientLiquidity();

        tokenA.safeTransfer(msg.sender, amountOut);
    }

    function _convert(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        } else if (toDecimals > fromDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        }
        return amount;
    }
}
