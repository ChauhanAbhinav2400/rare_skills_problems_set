// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VaultDepositTest is Test {
    Vault public vault;
    MockERC20 public mockToken;
    
    address public user = address(0x1);
    address public other = address(0x2);
    
    // Storage slot for _totalSupply in ERC20 is slot 2
    bytes32 constant TOTAL_SUPPLY_SLOT = bytes32(uint256(2));

    event Mint(address indexed from, uint256 amountAsset, uint256 shares);

    function setUp() public {
        mockToken = new MockERC20();
        vault = new Vault(mockToken);
        
        // Give users some tokens
        mockToken.mint(user, 1000e18);
        mockToken.mint(other, 1000e18);
    }

    function test_deposit_FirstDeposit_OneToOneRatio() public {
        uint256 depositAmount = 100e18;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        vault.deposit(depositAmount, depositAmount); // minSharesOut = depositAmount (1:1)
        vm.stopPrank();
        
        // Verify state changes
        assertEq(vault.balanceOf(user), depositAmount, "User should receive shares equal to deposit");
        assertEq(vault.totalSupply(), depositAmount, "Total supply should equal deposit");
        assertEq(mockToken.balanceOf(address(vault)), depositAmount, "Vault should hold the tokens");
        assertEq(mockToken.balanceOf(user), 1000e18 - depositAmount, "User balance should decrease");
    }

    function test_deposit_ExecutionOrder_TransferBeforeCompute() public {
        // This test will FAIL if deposit() transfers tokens before computing shares
        // because the balance would change, affecting the share calculation
        
        // First, seed vault with some tokens and shares to set up non-1:1 ratio
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(500e18))); // 500 shares outstanding
        mockToken.mint(address(vault), 1000e18); // 1000 assets in vault
        // Current ratio: 1 asset = 0.5 shares (or 1 share = 2 assets)
        
        uint256 depositAmount = 100e18;
        uint256 expectedShares = 50e18; // 100 * 500 / 1000 = 50
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        // If transfer happens before computation, the balance would be 1100e18
        // and shares would be: 100 * 500 / 1100 = 45.45... = 45
        // But with correct order, it should be: 100 * 500 / 1000 = 50
        
        vault.deposit(depositAmount, expectedShares); // Should pass with correct order
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), expectedShares, "Should receive correct shares based on pre-transfer balance");
    }

    function test_deposit_ExecutionOrder_WouldFailWithWrongOrder() public {
        // Demonstrate what would happen with wrong execution order
        // Set up scenario where wrong order would give different shares
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(100e18))); 
        mockToken.mint(address(vault), 200e18); 
        // Ratio: 1 asset = 0.5 shares
        
        uint256 depositAmount = 200e18;
        
        // Correct order calculation: 200 * 100 / 200 = 100 shares
        uint256 correctShares = 100e18;
        
        // Wrong order would calculate after transfer: 200 * 100 / 400 = 50 shares
        uint256 wrongOrderShares = 50e18;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        // Set minSharesOut to what wrong order would give
        // This should REVERT because correct implementation gives more shares
        vm.expectRevert(); // Should revert with Slippage error
        vault.deposit(depositAmount, correctShares + 1); // Expecting slightly more than correct
        
        // But asking for wrong-order amount should succeed
        vault.deposit(depositAmount, wrongOrderShares);
        vm.stopPrank();
        
        // Verify we got the correct (higher) amount, not the wrong order amount
        assertEq(vault.balanceOf(user), correctShares, "Should get correct shares, not wrong-order shares");
        assertTrue(vault.balanceOf(user) > wrongOrderShares, "Correct order should give more shares");
    }

    function test_deposit_SlippageProtection_ExactMin() public {
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 2000e18); // 1 asset = 0.5 shares
        
        uint256 depositAmount = 100e18;
        uint256 expectedShares = 50e18; // 100 * 1000 / 2000 = 50
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        // Should succeed with exact minimum
        vault.deposit(depositAmount, expectedShares);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), expectedShares);
    }

    function test_deposit_SlippageProtection_TooHighMin() public {
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 2000e18); // 1 asset = 0.5 shares
        
        uint256 depositAmount = 100e18;
        uint256 expectedShares = 50e18; // 100 * 1000 / 2000 = 50
        uint256 tooHighMin = expectedShares + 1;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        vm.expectRevert(); // Should revert with Slippage error
        vault.deposit(depositAmount, tooHighMin);
        vm.stopPrank();
    }

    function test_deposit_SlippageProtection_LowerMinPasses() public {
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 2000e18);
        
        uint256 depositAmount = 100e18;
        uint256 expectedShares = 50e18;
        uint256 lowerMin = expectedShares - 1;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        vault.deposit(depositAmount, lowerMin);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), expectedShares, "Should still get full amount even with lower min");
    }

    function test_deposit_MultipleUsers_IndependentShares() public {
        // First user deposits (1:1 ratio)
        vm.startPrank(user);
        mockToken.approve(address(vault), 100e18);
        vault.deposit(100e18, 100e18);
        vm.stopPrank();
        
        // Second user deposits (should still get fair ratio)
        vm.startPrank(other);
        mockToken.approve(address(vault), 200e18);
        // Expected: 200 * 100 / 100 = 200 shares
        vault.deposit(200e18, 200e18);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), 100e18, "First user should keep their shares");
        assertEq(vault.balanceOf(other), 200e18, "Second user should get proportional shares");
        assertEq(vault.totalSupply(), 300e18, "Total supply should be sum of all shares");
        assertEq(mockToken.balanceOf(address(vault)), 300e18, "Vault should hold all deposited tokens");
    }

    function test_deposit_ZeroAmount() public {
        vm.startPrank(user);
        mockToken.approve(address(vault), 0);
        
        vault.deposit(0, 0);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), 0, "Should mint 0 shares for 0 deposit");
        assertEq(mockToken.balanceOf(address(vault)), 0, "Vault should receive 0 tokens");
    }

    function test_deposit_InsufficientAllowance() public {
        vm.startPrank(user);
        // Don't approve tokens or approve insufficient amount
        mockToken.approve(address(vault), 50e18);
        
        vm.expectRevert(); // Should revert on transfer
        vault.deposit(100e18, 0);
        vm.stopPrank();
    }

    function test_deposit_InsufficientBalance() public {
        address poorUser = address(0x3);
        // poorUser has 0 tokens
        
        vm.startPrank(poorUser);
        mockToken.approve(address(vault), 100e18);
        
        vm.expectRevert(); // Should revert on transfer
        vault.deposit(100e18, 0);
        vm.stopPrank();
    }

    function test_deposit_PreExistingBalanceDoesNotAffectShares() public {
        // Someone accidentally sends tokens to vault (not through deposit)
        mockToken.mint(address(vault), 50e18); // Direct transfer, no shares minted
        
        // Now user deposits normally
        vm.startPrank(user);
        mockToken.approve(address(vault), 100e18);
        
        // Since totalSupply is still 0, should get 1:1 ratio despite pre-existing balance
        vault.deposit(100e18, 100e18);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), 100e18, "Should get 1:1 shares despite pre-existing vault balance");
        assertEq(mockToken.balanceOf(address(vault)), 150e18, "Vault should have original + deposited");
    }

    function test_deposit_RoundingDown_EdgeCase() public {
        // Set up scenario where shares calculation rounds down
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(3)));
        mockToken.mint(address(vault), 10);
        
        vm.startPrank(user);
        mockToken.approve(address(vault), 1);
        
        // 1 * 3 / 10 = 0.3 -> rounds down to 0
        vault.deposit(1, 0); // Must accept 0 shares
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), 0, "Should receive 0 shares due to rounding");
        assertEq(mockToken.balanceOf(address(vault)), 11, "Vault should still receive the token");
    }

    function test_deposit_MaxValues() public {
        // Test with large but safe values
        uint256 largeAmount = 1e30;
        mockToken.mint(user, largeAmount);
        
        vm.startPrank(user);
        mockToken.approve(address(vault), largeAmount);
        
        vault.deposit(largeAmount, largeAmount);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user), largeAmount, "Should handle large deposits");
        assertEq(vault.totalSupply(), largeAmount, "Should handle large total supply");
    }

    function test_deposit_EventEmission() public {
        uint256 depositAmount = 123e18;
        uint256 expectedShares = 123e18; // 1:1 for first deposit
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        // Test event emission
        vm.expectEmit(true, false, false, true);
        emit Mint(user, depositAmount, expectedShares);
        
        vault.deposit(depositAmount, expectedShares);
        vm.stopPrank();
    }

    function test_deposit_StateChangesAtomic() public {
        // Verify all state changes happen together (no partial state)
        uint256 depositAmount = 100e18;
        
        vm.startPrank(user);
        mockToken.approve(address(vault), depositAmount);
        
        // Record initial states
        uint256 initialUserTokens = mockToken.balanceOf(user);
        uint256 initialVaultTokens = mockToken.balanceOf(address(vault));
        uint256 initialUserShares = vault.balanceOf(user);
        uint256 initialTotalSupply = vault.totalSupply();
        
        vault.deposit(depositAmount, depositAmount);
        
        // All changes should have occurred
        assertEq(mockToken.balanceOf(user), initialUserTokens - depositAmount, "User tokens decreased");
        assertEq(mockToken.balanceOf(address(vault)), initialVaultTokens + depositAmount, "Vault tokens increased");
        assertEq(vault.balanceOf(user), initialUserShares + depositAmount, "User shares increased");
        assertEq(vault.totalSupply(), initialTotalSupply + depositAmount, "Total supply increased");
        
        vm.stopPrank();
    }
}