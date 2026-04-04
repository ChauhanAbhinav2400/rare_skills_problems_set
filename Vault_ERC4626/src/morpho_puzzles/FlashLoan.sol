// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IMorpho} from "morpho-blue/src/interfaces/IMorpho.sol";
import { IMorphoFlashLoanCallback } from "morpho-blue/src/interfaces/IMorphoCallbacks.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * PUZZLE: Flash Loan from Morpho Blue
 * 
 * SCENARIO:
 * You want to borrow 1,000 USDC from Morpho Blue using a flash loan.
 * A flash loan allows you to borrow assets without collateral, but you must
 * repay the loan plus any fees within the same transaction.
 * 
 * GIVEN:
 * - The Morpho Blue address is provided in the constructor and stored in `morpho`
 * - The `IMorpho` interface is available to interact with Morpho Blue
 * - The `IMorphoFlashLoanCallback` interface defines the callback function
 * - The token address is encoded in the `data` parameter of the callback
 * 
 * OBJECTIVE:
 * Implement the onMorphoFlashLoan() callback function to:
 * 1. Decode the token address from the `data` parameter
 * 2. Receive the borrowed assets from Morpho (they're already in this contract)
 * 3. Use the borrowed assets (in this case, just hold them temporarily)
 * 4. Approve Morpho to take back the borrowed amount
 * 5. Ensure Morpho can reclaim the full loan amount
 * 
 * HINT:
 * - Use `abi.decode(data, (address))` to extract the token address
 * - The borrowed tokens are already in this contract when the callback is called
 * - You only need to approve Morpho to pull them back
 * 
 * SUCCESS CRITERIA:
 * - The flash loan completes without reverting
 * - Morpho's balance is restored to its original amount
 * - This contract has no remaining funds after the flash loan
 * 
 * NOTE:
 * Morpho Blue flash loans are fee-free, so you only need to repay
 * the exact amount borrowed.
 */

contract FlashLoan is IMorphoFlashLoanCallback {
    IMorpho public immutable morpho;

    constructor(address _morpho) {
        morpho = IMorpho(_morpho);
    }

    // Trigger the flash loan
    function executeFlashLoan(address token, uint256 assets) external {
        bytes memory data = abi.encode(token);
        morpho.flashLoan(token, assets, data);
    }

    /**3
     * @notice Callback function called by Morpho during the flash loan.
     * After this function executes, the flash loan should complete without reverting.
     * 
     * @param assets The amount of tokens borrowed
     * @param data Encoded data containing the token address
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external override {
        // Add your code here
        address token = abi.decode(data,(address));

        // Approve Morpho to pull the borrowed amount back
        IERC20(token).approve(address(morpho), assets);
    }
}