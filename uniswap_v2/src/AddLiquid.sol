// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract AddLiquid {
    /**
     *  ADD LIQUIDITY WITHOUT ROUTER EXERCISE
     *
     *  The contract has an initial balance of 1000 USDC and 1 WETH.
     *  Mint a position (deposit liquidity) in the pool USDC/WETH to msg.sender.
     *  The challenge is to provide the same ratio as the pool then call the mint function in the pool contract.
     *
     */
    function addLiquidity(address usdc, address weth, address pool, uint256 usdcReserve, uint256 wethReserve) public {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        // your code start here
        uint256 usdcbalance = IERC20(usdc).balanceOf(address(this));
        uint256 wethbalance = IERC20(weth).balanceOf(address(this));

        uint256 usdcAmount;
        uint256 wethAmount;

        uint256 wethAmountRequired = (usdcbalance * wethReserve) / usdcReserve;


        if(wethbalance <= wethAmountRequired ){
            wethAmount = wethAmountRequired;
            usdcAmount = usdcbalance;
        }else{
            usdcAmount = (wethbalance * usdcReserve) / wethReserve;
            wethAmount = wethbalance;
        }

        IERC20(usdc).transfer(pool, usdcAmount);
        IERC20(weth).transfer(pool, wethAmount);

        pair.mint(msg.sender);

        // see available functions here: https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol

        // pair.getReserves();
        // pair.mint(...);
    }
}