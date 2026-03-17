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

contract VaultConvertToSharesTest is Test {
    Vault public vault;
    MockERC20 public mockToken;
    
    // Storage slot for _totalSupply in ERC20 is slot 2
    // slot 0: _balances mapping
    // slot 1: _allowances mapping  
    // slot 2: _totalSupply
    bytes32 constant TOTAL_SUPPLY_SLOT = bytes32(uint256(2));

    function setUp() public {
        mockToken = new MockERC20();
        vault = new Vault(mockToken);
    }

    function test_convertToShares_ZeroTotalSupply_ReturnsOneToOne() public {
        // When totalSupply is 0, should return 1:1 ratio
        uint256 amountAsset = 100e18;
        uint256 shares = vault.convertToShares(amountAsset);
        
        assertEq(shares, amountAsset, "Should return 1:1 when totalSupply is 0");
    }

    function test_convertToShares_ZeroTotalSupply_ZeroInput() public {
        // Edge case: zero input with zero totalSupply
        uint256 shares = vault.convertToShares(0);
        assertEq(shares, 0, "Should return 0 for 0 input when totalSupply is 0");
    }

    function test_convertToShares_EqualAssetAndSupply() public {
        // Set totalSupply to 1000e18 using vm.store
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        
        // Transfer 1000e18 tokens to vault (equal to totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Should maintain 1:1 ratio
        uint256 shares = vault.convertToShares(100e18);
        assertEq(shares, 100e18, "Should return 1:1 when asset balance equals totalSupply");
    }

    function test_convertToShares_MoreAssetsThanSupply() public {
        // Set totalSupply to 500e18
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(500e18)));
        
        // Transfer 1000e18 tokens to vault (2x totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Formula: amountAsset * totalSupply() / balance
        // 100e18 * 500e18 / 1000e18 = 50e18
        uint256 shares = vault.convertToShares(100e18);
        assertEq(shares, 50e18, "Should return fewer shares when assets > totalSupply");
    }

    function test_convertToShares_FewerAssetsThanSupply() public {
        // Set totalSupply to 2000e18  
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(2000e18)));
        
        // Transfer 1000e18 tokens to vault (0.5x totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Formula: amountAsset * totalSupply() / balance
        // 100e18 * 2000e18 / 1000e18 = 200e18
        uint256 shares = vault.convertToShares(100e18);
        assertEq(shares, 200e18, "Should return more shares when assets < totalSupply");
    }

    function test_convertToShares_RoundingDown() public {
        // Set totalSupply to 3
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(3)));
        
        // Transfer 10 tokens to vault
        mockToken.mint(address(vault), 10);
        
        // Formula: amountAsset * totalSupply() / balance
        // 1 * 3 / 10 = 0.3 -> rounds down to 0
        uint256 shares = vault.convertToShares(1);
        assertEq(shares, 0, "Should round down fractional shares");
        
        // 4 * 3 / 10 = 1.2 -> rounds down to 1
        shares = vault.convertToShares(4);
        assertEq(shares, 1, "Should round down fractional shares");
    }

    function test_convertToShares_LargeNumbers() public {
        // Test with large but safe numbers to avoid overflow
        uint256 largeTotalSupply = 1e30; // Large but safe
        uint256 largeBalance = 2e30; // Larger balance
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(largeTotalSupply));
        mockToken.mint(address(vault), largeBalance);
        
        uint256 amountAsset = 1e18;
        uint256 shares = vault.convertToShares(amountAsset);
        
        // Should not overflow and return expected result
        // Formula: 1e18 * 1e30 / 2e30 = 0.5e18
        uint256 expected = amountAsset * largeTotalSupply / largeBalance;
        assertEq(shares, expected, "Should handle large numbers without overflow");
        assertEq(shares, 5e17, "Should return half the input amount");
    }

    function test_convertToShares_SmallNumbers() public {
        // Test with very small numbers
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1)));
        mockToken.mint(address(vault), 1);
        
        uint256 shares = vault.convertToShares(1);
        assertEq(shares, 1, "Should work with smallest possible values");
    }

    function test_convertToShares_ZeroAssetInput() public {
        // Non-zero totalSupply and balance, but zero input
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 500e18);
        
        uint256 shares = vault.convertToShares(0);
        assertEq(shares, 0, "Should return 0 for 0 input regardless of ratios");
    }

    function test_convertToShares_VerySmallBalance() public {
        // Test edge case where balance is very small compared to totalSupply
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 1); // Very small balance
        
        // This should give a very high conversion rate
        uint256 shares = vault.convertToShares(1);
        uint256 expected = 1 * 1000e18 / 1; // = 1000e18
        assertEq(shares, expected, "Should handle very small balance correctly");
    }

    function test_convertToShares_MaxUintInputWithBalance() public {
        // Test maximum possible input that won't overflow
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1e18)));
        mockToken.mint(address(vault), 1e18);
        
        // With 1:1 ratio, use a large but safe value
        uint256 safeMax = type(uint256).max / 1e18;
        uint256 shares = vault.convertToShares(safeMax);
        assertEq(shares, safeMax, "Should handle large inputs when ratio is 1:1");
    }
}