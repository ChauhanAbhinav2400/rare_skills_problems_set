// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IMorpho, MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * PUZZLE: Liquidate an Unhealthy Position on Morpho Blue
 * 
 * SCENARIO:
 * You have 10,000 USDC in this contract.
 * A borrower has taken a loan on Morpho Blue using WETH as collateral.
 * The price of WETH has crashed, making their position unhealthy (underwater).
 * You can liquidate their position to earn a profit.
 * 
 * GIVEN:
 * - The Morpho Blue address is provided in the constructor and stored in `morpho`
 * - The `IMorpho` interface is available to interact with Morpho Blue
 * - Market parameters are passed as a function parameter
 * - The borrower's address is passed as a function parameter
 * 
 * OBJECTIVE:
 * Implement the liquidatePosition() function to:
 * 1. Get the loan token address from marketParams (it's USDC)
 * 2. Approve Morpho to spend USDC (to repay the borrower's debt)
 * 3. Call Morpho's liquidate function to repay part of the debt
 * 4. Receive the borrower's collateral (WETH) as a reward
 * 5. The liquidation bonus means you receive more value than you paid
 * 
 * HINT:
 * Look for the `liquidate()` function in the IMorpho interface.
 * It takes marketParams, borrower address, seized collateral amount, and repaid assets.
 * You can pass 0 for seized collateral to let Morpho calculate it automatically.
 * 
 * SUCCESS CRITERIA:
 * - The borrower's debt is reduced
 * - This contract receives WETH collateral
 * - You profit from the liquidation bonus
 * 
 * LIQUIDATION MECHANICS:
 * When you liquidate, you repay some of the borrower's debt and receive
 * their collateral at a discount (liquidation bonus), allowing you to profit.
 */
contract Liquidate {
    IMorpho public immutable morpho;

    constructor(address _morpho) {
        morpho = IMorpho(_morpho);
    }

    /**
     * @notice Liquidates an unhealthy borrower's position.
     *
     * After this function executes:
     * - The borrower's debt should be reduced
     * - This contract should receive collateral
     * 
     * @param marketParams The market parameters for the position
     * @param borrower The address of the borrower to liquidate
     * @param amountToRepay The amount of debt to repay (in loan tokens)
     */
    function liquidatePosition(
        MarketParams calldata marketParams,
        address borrower,
        uint256 amountToRepay
    ) external {
        // Add your code here
    }
}