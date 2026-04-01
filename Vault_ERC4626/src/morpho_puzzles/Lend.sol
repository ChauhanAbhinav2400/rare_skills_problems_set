// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IVaultV2 } from "@morpho-org/vault-v2/src/interfaces/IVaultV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * PUZZLE: Lend to Morpho Vault
 * 
 * SCENARIO:
 * You have 1,000 USDC in this contract.
 * Your goal is to deposit USDC into the Morpho Vault to earn yield.
 * 
 * GIVEN:
 * - The vault address is provided in the constructor and stored in `vault`
 * - The `IVaultV2` interface is available to interact with the vault
 * - Use `vault.asset()` to get the underlying token address (USDC)
 * 
 * OBJECTIVE:
 * Implement the supplyAsset() function to:
 * 1. Get the underlying asset address from the vault
 * 2. Approve the vault to spend USDC from this contract
 * 3. Deposit the specified amount of USDC into the vault
 * 4. Receive vault shares in return
 * 
 * HINT:
 * The IVaultV2 interface follows the ERC-4626 standard.
 * Look for a function like `deposit(uint256 assets, address receiver)`
 * 
 * SUCCESS CRITERIA:
 * - This contract holds vault shares after execution
 * - The vault shares represent your deposited USDC
 */
contract Lend {

    IVaultV2 public immutable vault;

    constructor(address _vault) {
        vault = IVaultV2(_vault);
    }

    /**
     * @notice After this function executes,
     * this contract should have vault shares.
     * @param amount The amount of underlying asset to deposit
     */
    function supplyAsset(uint256 amount) external {
        // Add your code here
        address asset = vault.asset();

        IERC20(asset).approve(address(vault),amount);
        vault.deposit(amount,address(this));
    }
}