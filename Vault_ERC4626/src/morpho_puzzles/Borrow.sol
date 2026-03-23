// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMorpho, MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";

/**
 * PUZZLE: Borrow from Morpho Blue
 * 
 * SCENARIO:
 * You have 10 WETH in this contract.
 * You want to borrow USDT against your WETH collateral using Morpho Blue.
 * 
 * GIVEN:
 * - The Morpho Blue address is provided in the constructor and stored in `morpho`
 * - The market parameters are provided in the constructor and stored in `marketParams`
 * - The `IMorpho` interface is available to interact with Morpho Blue
 * - Market params specify: loanToken (USDT), collateralToken (WETH), oracle, IRM, and LLTV
 * 
 * OBJECTIVE:
 * Implement the addCollateralAndBorrow() function to:
 * 1. Get the collateral token address from marketParams
 * 2. Approve Morpho to spend your WETH collateral
 * 3. Supply WETH as collateral to the Morpho market
 * 4. Borrow USDT against your collateral
 * 5. Ensure you maintain a healthy loan-to-value ratio
 * 
 * HINT:
 * Morpho Blue has separate functions for supplying collateral and borrowing.
 * Look for `supplyCollateral()` and `borrow()` in the IMorpho interface.
 * 
 * SUCCESS CRITERIA:
 * - This contract has an open borrow position on Morpho
 * - The borrowed USDT is in this contract
 * - The WETH collateral is locked in Morpho
 */
contract Borrow {
    IMorpho public immutable morpho;
    MarketParams public marketParams;

    constructor(IMorpho _morpho, MarketParams memory _marketParams) {
        morpho = _morpho;
        marketParams = _marketParams;
    }

    /**
     * @notice Deposit collateral and borrow assets from the Morpho market.
     *
     * After this function executes, this contract should have
     * an open borrow position.
     * 
     * @param collateralAmount The amount of WETH to deposit as collateral
     * @param borrowAmount The amount of USDT to borrow
     */
    function addCollateralAndBorrow(uint256 collateralAmount, uint256 borrowAmount) external {
        // Add your code here
    }
}