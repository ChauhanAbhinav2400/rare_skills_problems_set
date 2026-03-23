// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import { FlashLoan } from "../src/FlashLoan.sol";
import { IMorpho } from "morpho-blue/src/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashLoanTest is Test {
    // Real Morpho Blue contract
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    // Token supported for flash loans (USDC)
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    FlashLoan flashLoan;

    function setUp() public {
        // Fork Ethereum mainnet
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        
        // Deploy the puzzle contract
        flashLoan = new FlashLoan(address(MORPHO));
    }

    function testFlashLoan() public {
        uint256 amount = 1_000e6; // 1,000 USDC

        // Record Morpho's balance before the flash loan
        uint256 morphoBalanceBefore = USDC.balanceOf(address(MORPHO));

        // Ensure the flash loan contract starts with no USDC
        assertEq(USDC.balanceOf(address(flashLoan)), 0, "Contract should start with 0 USDC");

        // Execute flash loan
        flashLoan.executeFlashLoan(address(USDC), amount);

        // Record balances after the flash loan
        uint256 morphoBalanceAfter = USDC.balanceOf(address(MORPHO));
        uint256 contractBalance = USDC.balanceOf(address(flashLoan));

        // Verify Morpho was fully repaid (balance should be unchanged)
        assertEq(
            morphoBalanceAfter,
            morphoBalanceBefore,
            "Morpho not fully repaid"
        );

        // Verify the flash loan contract kept no funds
        assertEq(
            contractBalance,
            0,
            "Flash loan contract should not retain funds"
        );
    }

    function testFlashLoanLargerAmount() public {
        uint256 amount = 10_000e6; // 10,000 USDC

        uint256 morphoBalanceBefore = USDC.balanceOf(address(MORPHO));

        // Execute flash loan with larger amount
        flashLoan.executeFlashLoan(address(USDC), amount);

        uint256 morphoBalanceAfter = USDC.balanceOf(address(MORPHO));

        // Verify full repayment
        assertEq(
            morphoBalanceAfter,
            morphoBalanceBefore,
            "Morpho not fully repaid for larger amount"
        );

        // Verify no funds retained
        assertEq(
            USDC.balanceOf(address(flashLoan)),
            0,
            "Contract should not retain funds"
        );
    }

    function testFlashLoanCallback() public {
        uint256 amount = 500e6; // 500 USDC

        uint256 morphoBalanceBefore = USDC.balanceOf(address(MORPHO));
        
        // Execute the flash loan - should complete successfully without reverting
        flashLoan.executeFlashLoan(address(USDC), amount);

        // Verify the flash loan was properly repaid
        uint256 morphoBalanceAfter = USDC.balanceOf(address(MORPHO));
        assertEq(
            morphoBalanceAfter,
            morphoBalanceBefore,
            "Flash loan callback did not properly repay"
        );

        // Verify contract has no remaining balance
        assertEq(
            USDC.balanceOf(address(flashLoan)),
            0,
            "Contract should have no remaining balance after callback"
        );
    }
}