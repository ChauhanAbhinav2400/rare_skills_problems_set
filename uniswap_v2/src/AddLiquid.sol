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

         uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        // Step 2: Calculate optimal WETH based on full USDC (limiting side)
        uint256 amountWethOptimal = (usdcBalance * wethReserve) / usdcReserve;

        uint256 amountUsdc;
        uint256 amountWeth;

        if (amountWethOptimal <= wethBalance) {
            // USDC is limiting
            amountUsdc = usdcBalance;
            amountWeth = amountWethOptimal;
        } else {
            // WETH is limiting (fallback case)
            uint256 amountUsdcOptimal = (wethBalance * usdcReserve) / wethReserve;

            amountUsdc = amountUsdcOptimal;
            amountWeth = wethBalance;
        }

        // Step 3: Transfer tokens to the pair
        IERC20(usdc).transfer(pool, amountUsdc);
        IERC20(weth).transfer(pool, amountWeth);

        // Step 4: Mint LP tokens to msg.sender
        pair.mint(msg.sender);

        // see available functions here: https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol

        // pair.getReserves();
        // pair.mint(...);
    }
}