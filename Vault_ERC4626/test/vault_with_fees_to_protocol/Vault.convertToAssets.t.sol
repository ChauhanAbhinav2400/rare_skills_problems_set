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

contract VaultConvertToAssetsTest is Test {
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

    function test_convertToAssets_ZeroTotalSupply_ReturnsOneToOne() public {
        // When totalSupply is 0, should return 1:1 ratio
        uint256 amountShares = 100e18;
        uint256 assets = vault.convertToAssets(amountShares);
        
        assertEq(assets, amountShares, "Should return 1:1 when totalSupply is 0");
    }

    function test_convertToAssets_ZeroTotalSupply_ZeroInput() public {
        // Edge case: zero input with zero totalSupply
        uint256 assets = vault.convertToAssets(0);
        assertEq(assets, 0, "Should return 0 for 0 input when totalSupply is 0");
    }

    function test_convertToAssets_EqualAssetAndSupply() public {
        // Set totalSupply to 1000e18 using vm.store
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        
        // Transfer 1000e18 tokens to vault (equal to totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Should maintain 1:1 ratio
        uint256 assets = vault.convertToAssets(100e18);
        assertEq(assets, 100e18, "Should return 1:1 when asset balance equals totalSupply");
    }

    function test_convertToAssets_MoreAssetsThanSupply() public {
        // Set totalSupply to 500e18
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(500e18)));
        
        // Transfer 1000e18 tokens to vault (2x totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Formula: amountShares * balance / totalSupply()
        // 100e18 * 1000e18 / 500e18 = 200e18
        uint256 assets = vault.convertToAssets(100e18);
        assertEq(assets, 200e18, "Should return more assets when vault balance > totalSupply");
    }

    function test_convertToAssets_FewerAssetsThanSupply() public {
        // Set totalSupply to 2000e18  
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(2000e18)));
        
        // Transfer 1000e18 tokens to vault (0.5x totalSupply)
        mockToken.mint(address(vault), 1000e18);
        
        // Formula: amountShares * balance / totalSupply()
        // 100e18 * 1000e18 / 2000e18 = 50e18
        uint256 assets = vault.convertToAssets(100e18);
        assertEq(assets, 50e18, "Should return fewer assets when vault balance < totalSupply");
    }

    function test_convertToAssets_RoundingDown() public {
        // Set totalSupply to 10
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(10)));
        
        // Transfer 3 tokens to vault
        mockToken.mint(address(vault), 3);
        
        // Formula: amountShares * balance / totalSupply()
        // 1 * 3 / 10 = 0.3 -> rounds down to 0
        uint256 assets = vault.convertToAssets(1);
        assertEq(assets, 0, "Should round down fractional assets");
        
        // 4 * 3 / 10 = 1.2 -> rounds down to 1
        assets = vault.convertToAssets(4);
        assertEq(assets, 1, "Should round down fractional assets");
        
        // 7 * 3 / 10 = 2.1 -> rounds down to 2
        assets = vault.convertToAssets(7);
        assertEq(assets, 2, "Should round down fractional assets");
    }

    function test_convertToAssets_LargeNumbers() public {
        // Test with large but safe numbers to avoid overflow
        uint256 largeTotalSupply = 1e30; // Large total supply
        uint256 largeBalance = 2e30; // Larger balance
        
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(largeTotalSupply));
        mockToken.mint(address(vault), largeBalance);
        
        uint256 amountShares = 1e18;
        uint256 assets = vault.convertToAssets(amountShares);
        
        // Formula: 1e18 * 2e30 / 1e30 = 2e18
        uint256 expected = amountShares * largeBalance / largeTotalSupply;
        assertEq(assets, expected, "Should handle large numbers without overflow");
        assertEq(assets, 2e18, "Should return double the shares amount");
    }

    function test_convertToAssets_SmallNumbers() public {
        // Test with very small numbers
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1)));
        mockToken.mint(address(vault), 1);
        
        uint256 assets = vault.convertToAssets(1);
        assertEq(assets, 1, "Should work with smallest possible values");
    }

    function test_convertToAssets_ZeroSharesInput() public {
        // Non-zero totalSupply and balance, but zero shares input
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000e18)));
        mockToken.mint(address(vault), 500e18);
        
        uint256 assets = vault.convertToAssets(0);
        assertEq(assets, 0, "Should return 0 for 0 shares regardless of ratios");
    }

    function test_convertToAssets_VeryLargeBalance() public {
        // Test edge case where balance is very large compared to totalSupply
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1)));
        mockToken.mint(address(vault), 1000e18); // Very large balance
        
        // This should give a very high conversion rate
        uint256 assets = vault.convertToAssets(1);
        uint256 expected = 1 * 1000e18 / 1; // = 1000e18
        assertEq(assets, expected, "Should handle very large balance correctly");
    }

    function test_convertToAssets_MaxSharesWithBalance() public {
        // Test large shares input with 1:1 ratio
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1e30)));
        mockToken.mint(address(vault), 1e30);
        
        // With 1:1 ratio, large input should return same amount
        uint256 largeShares = 1e25; // Large but safe value
        uint256 assets = vault.convertToAssets(largeShares);
        assertEq(assets, largeShares, "Should handle large shares input when ratio is 1:1");
    }

    function test_convertToAssets_PrecisionTest() public {
        // Test precision with specific numbers
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(1000)));
        mockToken.mint(address(vault), 1500); // 1.5:1 ratio
        
        // 100 shares * 1500 assets / 1000 totalSupply = 150 assets
        uint256 assets = vault.convertToAssets(100);
        assertEq(assets, 150, "Should calculate precise ratios correctly");
        
        // 333 shares * 1500 assets / 1000 totalSupply = 499.5 -> 499 (rounds down)
        assets = vault.convertToAssets(333);
        assertEq(assets, 499, "Should handle precision and rounding correctly");
    }

    function test_convertToAssets_VerySmallTotalSupply() public {
        // Test with minimal totalSupply but larger balance
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(2)));
        mockToken.mint(address(vault), 1000e18);
        
        // Each share is worth a lot of assets
        uint256 assets = vault.convertToAssets(1);
        uint256 expected = 1 * 1000e18 / 2; // = 500e18
        assertEq(assets, expected, "Should handle very small totalSupply correctly");
    }

    function test_convertToAssets_ExactDivision() public {
        // Test cases where division is exact (no remainder)
        vm.store(address(vault), TOTAL_SUPPLY_SLOT, bytes32(uint256(4)));
        mockToken.mint(address(vault), 8);
        
        // 2 shares * 8 assets / 4 totalSupply = 4 assets (exact)
        uint256 assets = vault.convertToAssets(2);
        assertEq(assets, 4, "Should handle exact division correctly");
        
        // 1 share * 8 assets / 4 totalSupply = 2 assets (exact)
        assets = vault.convertToAssets(1);
        assertEq(assets, 2, "Should handle exact division correctly");
    }
}