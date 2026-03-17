//SPDX-License-Identifier :MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


// tokenA and tokenB are stablecoins, so they have the same value, but different
// decimals. This contract allows users to trade one token for another at equal rate
// after correcting for the decimals difference 
contract DecimalSwap {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public immutable tokenA;
    IERC20Metadata public immutable tokenB;

    constructor(address tokenA_, address tokenB_) {
      tokenA = IERC20Metadata(tokenA_);
      tokenB = IERC20Metadata(tokenB_);
    }

    function swapAtoB(uint256 amountIn) external {
        uint8 decimalsA = tokenA.decimals();
        uint8 decimalsB = tokenB.decimals();
        uint256 amountOut;
        if(decimalsA > decimalsB) {
            amountOut = amountIn / (10 ** (decimalsA - decimalsB));
        }
        else if( decimalsB > decimalsA) {
            amountOut = amountIn * (10 ** (decimalsB - decimalsA));
        }
        else{
            amountOut = amountIn;
        }
        tokenA.safeTransferFrom(msg.sender, address(this) , amountIn);
        tokenB.safeTransfer(msg.sender , amountOut);
    }

    function swapBtoA(uint256 amountIn) external {
       uint8 decimalsA = tokenA.decimals();
        uint8 decimalsB = tokenB.decimals();
        uint256 amountOut;
        if(decimalsB > decimalsA) {
            amountOut = amountIn / (10 ** (decimalsB - decimalsA));
        }
        else if( decimalsA > decimalsB) {
            amountOut = amountIn * (10 ** (decimalsA - decimalsB));
        }
        else{
            amountOut = amountIn;
        }
        tokenB.safeTransferFrom(msg.sender, address(this) , amountIn);
        tokenA.safeTransfer(msg.sender , amountOut);
    }
}