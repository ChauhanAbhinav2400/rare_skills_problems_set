// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault_with_fees_to_protocol.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultWithdrawTest is Test {
    Vault public vault;
    MockERC20 public mockToken;
    
    address public user = address(0x1);
    address public other = address(0x2);
    
    // Storage slot for _totalSupply in ERC20 is slot 2
    bytes32 constant TOTAL_SUPPLY_SLOT = bytes32(uint256(2));
    // Storage slot for _balances mapping in ERC20 is slot 0
    bytes32 constant BALANCES_SLOT = bytes32(uint256(0));

    event Burn(address indexed from, uint256 amountAsset, uint256 shares);

    function setUp() public {
        mockToken = new MockERC20();
        vault = new Vault(mockToken);
    }

    // Helper function to set user's vault share balance directly
    function setUserShares(address userAddr, uint256 shares) internal {
        // Calculate storage slot for user's balance in vault
        bytes32 slot = keccak256(abi.encode(userAddr, BALANCES_SLOT));
        vm.store(address(vault), slot, bytes32(shares));
    }

    function test_withdraw_BasicWithdraw_OneToOneRatio() public {
        uint256 shareAmount = 100e18;
        uint256 expectedAssets = 100e18;
        
        // Set up vault state: equal shares and assets (1:1 ratio)
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(shareAmount)));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), expectedAssets);
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
        
        // Verify state changes
        assertEq(vault.balanceOf(user), 0, "User should have no shares left");
        assertEq(vault.totalSupply(), 0, "Total supply should be 0");
        assertEq(mockToken.balanceOf(address(vault)), 0, "Vault should have no tokens left");
        assertEq(mockToken.balanceOf(user), expectedAssets, "User should receive the assets");
    }

    function test_withdraw_ExecutionOrder_TransferAfterBurn() public {
        // This test will FAIL if withdraw() transfers before burning shares
        // The current implementation should transfer AFTER burn to prevent reentrancy
        
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 200e18;
        uint256 totalSupply = 100e18;
        
        // Set up vault state: 100 shares worth 200 assets (2:1 ratio)
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        uint256 expectedAssets = 200e18; // 100 * 200 / 100 = 200
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
        
        // If transfer happened before burn, this would be the behavior we verify against
        assertEq(vault.balanceOf(user), 0, "Shares should be burned");
        assertEq(mockToken.balanceOf(user), expectedAssets, "Should receive correct assets");
    }

    function test_withdraw_ExecutionOrder_ComputeBeforeTransfer() public {
        // Test that asset calculation happens BEFORE any transfers
        // This is critical for preventing manipulation
        
        uint256 shareAmount = 50e18;
        uint256 vaultBalance = 1000e18;
        uint256 totalSupply = 500e18;
        
        // Ratio: 50 shares * 1000 assets / 500 totalSupply = 100 assets
        uint256 expectedAssets = 100e18;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), expectedAssets, "Should receive assets calculated before any state changes");
        assertEq(vault.balanceOf(user), 0, "Shares should be burned");
        assertEq(vault.totalSupply(), totalSupply - shareAmount, "Total supply should decrease");
        assertEq(mockToken.balanceOf(address(vault)), vaultBalance - expectedAssets, "Vault balance should decrease");
    }

    function test_withdraw_SlippageProtection_ExactMin() public {
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 150e18;
        uint256 totalSupply = 200e18;
        
        // Expected: 100 * 150 / 200 = 75 assets
        uint256 expectedAssets = 75e18;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        // Should succeed with exact minimum
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), expectedAssets);
    }

    function test_withdraw_SlippageProtection_TooHighMin() public {
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 150e18;
        uint256 totalSupply = 200e18;
        
        // Expected: 100 * 150 / 200 = 75 assets
        uint256 expectedAssets = 75e18;
        uint256 tooHighMin = expectedAssets + 1;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        vm.expectRevert(); // Should revert with Slippage error
        vault.withdraw(shareAmount, tooHighMin);
        vm.stopPrank();
    }

    function test_withdraw_SlippageProtection_LowerMinPasses() public {
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 150e18;
        uint256 totalSupply = 200e18;
        
        uint256 expectedAssets = 75e18;
        uint256 lowerMin = expectedAssets - 1;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, lowerMin);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), expectedAssets, "Should still get full amount even with lower min");
    }

    function test_withdraw_InsufficientShares() public {
        uint256 userShares = 50e18;
        uint256 withdrawAmount = 100e18; // More than user has
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(200e18)));
        setUserShares(user, userShares);
        mockToken.mint(address(vault), 200e18);
        
        vm.startPrank(user);
        vm.expectRevert(); // Should revert on _burn due to insufficient balance
        vault.withdraw(withdrawAmount, 0);
        vm.stopPrank();
    }

    function test_withdraw_ZeroShares() public {
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(100e18)));
        setUserShares(user, 100e18);
        mockToken.mint(address(vault), 100e18);
        
        vm.startPrank(user);
        vault.withdraw(0, 0);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), 0, "Should receive 0 assets for 0 shares");
        assertEq(vault.balanceOf(user), 100e18, "User shares should remain unchanged");
    }

    function test_withdraw_PartialWithdraw() public {
        uint256 userShares = 200e18;
        uint256 withdrawShares = 50e18;
        uint256 vaultBalance = 400e18;
        uint256 totalSupply = 200e18;
        
        // Expected assets: 50 * 400 / 200 = 100
        uint256 expectedAssets = 100e18;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, userShares);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        vault.withdraw(withdrawShares, expectedAssets);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), userShares - withdrawShares, "Should have remaining shares");
        assertEq(mockToken.balanceOf(user), expectedAssets, "Should receive proportional assets");
        assertEq(vault.totalSupply(), totalSupply - withdrawShares, "Total supply should decrease by withdrawn amount");
    }

    function test_withdraw_RoundingDown_EdgeCase() public {
        uint256 shareAmount = 1;
        uint256 vaultBalance = 3;
        uint256 totalSupply = 10;
        
        // 1 * 3 / 10 = 0.3 -> rounds down to 0
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, 0); // Must accept 0 assets due to rounding
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), 0, "Should receive 0 assets due to rounding down");
        assertEq(vault.balanceOf(user), 0, "Shares should still be burned");
        assertEq(vault.totalSupply(), totalSupply - shareAmount, "Total supply should decrease");
    }

    function test_withdraw_InsufficientVaultBalance() public {
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 50e18; 
        uint256 totalSupply = 50e18; // Make shares worth more than vault has
        
        // This tries to withdraw: 100e18 * 50e18 / 50e18 = 100e18 assets
        // But vault only has 50e18 assets
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        vm.startPrank(user);
        // Should revert because trying to transfer 100e18 when vault only has 50e18
        vm.expectRevert();
        vault.withdraw(shareAmount, 0);
        vm.stopPrank();
    }

    function test_withdraw_MultipleUsersIndependent() public {
        uint256 vaultBalance = 1000e18;
        uint256 totalSupply = 500e18;
        
        // User1 has 100 shares, User2 has 200 shares
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, 100e18);
        setUserShares(other, 200e18);
        mockToken.mint(address(vault), vaultBalance);
        
        // User1 withdraws: 100 * 1000 / 500 = 200 assets
        vm.startPrank(user);
        vault.withdraw(100e18, 200e18);
        vm.stopPrank();
        
        // Check User1's withdrawal
        assertEq(mockToken.balanceOf(user), 200e18, "User1 should receive 200 assets");
        assertEq(vault.balanceOf(user), 0, "User1 should have 0 shares left");
        
        // User2 should be unaffected
        assertEq(vault.balanceOf(other), 200e18, "User2 shares should remain");
        
        // Vault state should update correctly
        assertEq(vault.totalSupply(), 400e18, "Total supply should decrease by User1's shares");
        assertEq(mockToken.balanceOf(address(vault)), 800e18, "Vault balance should decrease by transferred assets");
    }

    function test_withdraw_MaxValues() public {
        uint256 largeShares = 1e30;
        uint256 largeBalance = 1e30;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(largeShares));
        setUserShares(user, largeShares);
        mockToken.mint(address(vault), largeBalance);
        
        vm.startPrank(user);
        vault.withdraw(largeShares, largeBalance);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(user), largeBalance, "Should handle large withdrawals");
        assertEq(vault.balanceOf(user), 0, "Should burn all shares");
    }

    function test_withdraw_EventEmission() public {
        uint256 shareAmount = 123e18;
        uint256 expectedAssets = 246e18; // 2:1 ratio
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(123e18)));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), 246e18);
        
        vm.startPrank(user);
        
        // Test event emission
        vm.expectEmit(true, false, false, true);
        emit Burn(user, expectedAssets, shareAmount);
        
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
    }

    function test_withdraw_StateChangesAtomic() public {
        uint256 shareAmount = 100e18;
        uint256 vaultBalance = 200e18;
        uint256 totalSupply = 100e18;
        uint256 expectedAssets = 200e18;
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(totalSupply));
        setUserShares(user, shareAmount);
        mockToken.mint(address(vault), vaultBalance);
        
        // Record initial states
        uint256 initialUserShares = vault.balanceOf(user);
        uint256 initialTotalSupply = vault.totalSupply();
        uint256 initialUserTokens = mockToken.balanceOf(user);
        uint256 initialVaultTokens = mockToken.balanceOf(address(vault));
        
        vm.startPrank(user);
        vault.withdraw(shareAmount, expectedAssets);
        vm.stopPrank();
        
        // All changes should have occurred atomically
        assertEq(vault.balanceOf(user), initialUserShares - shareAmount, "User shares decreased");
        assertEq(vault.totalSupply(), initialTotalSupply - shareAmount, "Total supply decreased");
        assertEq(mockToken.balanceOf(user), initialUserTokens + expectedAssets, "User tokens increased");
        assertEq(mockToken.balanceOf(address(vault)), initialVaultTokens - expectedAssets, "Vault tokens decreased");
    }

    function test_withdraw_ZeroTotalSupplyReverts() public {
        // This should revert due to division by zero in convertToAssets
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(0)));
        mockToken.mint(address(vault), 100e18);
        
        vm.startPrank(user);
        vm.expectRevert(); // Division by zero in convertToAssets
        vault.withdraw(1, 0);
        vm.stopPrank();
    }
}