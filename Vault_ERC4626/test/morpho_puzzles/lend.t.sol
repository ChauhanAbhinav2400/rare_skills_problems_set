// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import { Lend } from "../../src/morpho_puzzles/Lend.sol";
import { IVaultV2 } from "@morpho-org/vault-v2/src/interfaces/IVaultV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendTest is Test {
    
    // Real Morpho Vault (USDC)
    IVaultV2 constant VAULT = IVaultV2(0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB);
    
    // Underlying asset of the vault
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    Lend lend;

    function setUp() public {
        // Fork Ethereum mainnet so we can interact with real contracts
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        // Deploy the puzzle contract, pointing it at the real vault
        lend = new Lend(address(VAULT));

        // Mint 1,000 USDC directly to the puzzle contract
        deal(address(USDC), address(lend), 1_000e6);
        
        // Verify the contract has the expected starting balance
        assertEq(USDC.balanceOf(address(lend)), 1_000e6, "Initial USDC balance incorrect");
    }

    function testDepositAsLender() public {
        uint256 depositAmount = 500e6;
        
        // Record initial balances
        uint256 initialUSDC = USDC.balanceOf(address(lend));
        uint256 initialShares = VAULT.balanceOf(address(lend));

        // Execute the puzzle logic
        lend.supplyAsset(depositAmount);

        // Verify vault shares were received
        uint256 finalShares = VAULT.balanceOf(address(lend));
        assertGt(finalShares, initialShares, "No vault shares minted");
        
        // Verify USDC was spent
        uint256 finalUSDC = USDC.balanceOf(address(lend));
        assertEq(finalUSDC, initialUSDC - depositAmount, "USDC not spent correctly");
        
        // Verify shares represent value
        assertGt(finalShares, 0, "Shares balance should be greater than 0");
    }
    
    function testDepositFullBalance() public {

        uint256 depositAmount = 1_000e6;
        
        // Execute the puzzle logic with full balance
        lend.supplyAsset(depositAmount);

        // Verify all USDC was deposited
        assertEq(USDC.balanceOf(address(lend)), 0, "USDC should be fully deposited");
        
        // Verify shares were received
        assertGt(VAULT.balanceOf(address(lend)), 0, "No vault shares minted");
    }
}
