//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract OraclePool is Ownable2Step {
    using SafeERC20 for IERC20;

    IERC20 public immutable WETH;
    IERC20 public immutable STABLECOIN; // NOTE: has 6 decimals
    uint256 immutable feeBasisPoints;
    uint256 public ethToUSDRate; // 8 decimals. 2000_00000000 -> 1 ETH is 2000 USD.


    error InsufficientReserves();
    error Slippage(); // amountIn is not enough for amountOutMin

    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event SwapWethToStable(address indexed user, uint256 weth, uint256 stable);
    event SwapStableToWeth(address indexed user, uint256 stable, uint256 weth);

    constructor(
        address _weth,
        address _stableCoin,
        uint256 _feeBasisPoints,
        uint256 _ethToUSDRate) Ownable(msg.sender) 
        {

         WETH = IERC20(_weth);
         STABLECOIN = IERC20(_stableCoin);
         feeBasisPoints=_feeBasisPoints;
            ethToUSDRate = _ethToUSDRate;

        }
    

   function buyWETH(uint256 amountStableIn , uint256 amountOutMin) external returns(uint256) {
       uint256 usdValue = amountStableIn * 1e2;
       uint256 wethAmount = (usdValue *1e18) / ethToUSDRate;

       uint256 fee = (wethAmount * feeBasisPoints) / 10_000;
       uint256 amountOut = wethAmount - fee;

       if(amountOut < amountOutMin) revert Slippage();
       if(WETH.balanceOf(address(this)) < amountOut) revert InsufficientReserves();

       STABLECOIN.safeTransferFrom(msg.sender , address(this) , amountStableIn);
       WETH.safeTransfer(msg.sender , amountOut);
       emit SwapStableToWeth(msg.sender , amountStableIn , amountOut);
       return amountOut;
   }



   function sellWETH(uint256 amountIn , uint256 amountOutMin) external returns(uint256){
    uint256 usdValue =( amountIn * ethToUSDRate) / 1e18;
    uint256 stableAmount = usdValue / 1e2;

    uint256 fee = (stableAmount * feeBasisPoints) / 10_000;
    uint256 amountOut = stableAmount - fee;

    if(amountOut < amountOutMin) revert Slippage();
    if(STABLECOIN.balanceOf(address(this)) < amountOut ) revert InsufficientReserves();

    WETH.safeTransferFrom(msg.sender , address(this) , amountIn);
    STABLECOIN.safeTransfer(msg.sender , amountOut);
    emit SwapWethToStable(msg.sender , amountIn , amountOut);
    return amountOut;
    
   }


   function setExchangeRate(uint256 newRate) external onlyOwner{
    uint256 oldrate = ethToUSDRate;
    ethToUSDRate = newRate;
    emit ExchangeRateUpdated(oldrate, newRate);
}

}