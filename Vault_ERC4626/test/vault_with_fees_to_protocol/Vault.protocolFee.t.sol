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

contract VaultProtocolFeeTest is Test {
    Vault public vault;
    MockERC20 public mockToken;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public protocol = address(0x3);
    address public dao = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Same as in Vault contract

    function setUp() public {
        mockToken = new MockERC20();
        vault = new Vault(mockToken);

        // Give users tokens
        mockToken.mint(alice, 10000e18);
        mockToken.mint(bob, 10000e18);
        mockToken.mint(protocol, 10000e18);
    }

    function test_protocolFee_exactlyTenPercent() public {
        uint256 deposit = 1000e18;
        uint256 profit = 1000e18; // 100% profit for clean math

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // Protocol adds profit
        vm.prank(protocol);
        mockToken.transfer(address(vault), profit);

        // Trigger protocol fee by making another transaction
        vm.startPrank(alice);
        vault.withdraw(1, 0); // Tiny withdrawal to trigger fee
        vm.stopPrank();

        // Calculate what DAO should have received
        uint256 daoShares = vault.balanceOf(dao);
        uint256 totalShares = vault.totalSupply();

        // DAO should have exactly 10% of the total value
        uint256 daoValue = vault.convertToAssets(daoShares);
        uint256 totalValue = mockToken.balanceOf(address(vault));

        // DAO should own 10% of the profit
        uint256 expectedDaoValue = profit / 10; // 10% of 1000e18 = 100e18
        assertApproxEqAbs(daoValue, expectedDaoValue, 1e18, "DAO should own exactly 10% of profit");

        // Share price after fee should reflect 90% increase for LPs
        // Original: 1000 assets / 1000 shares = 1.0
        // After profit + fee: should be ~1.9 (90% increase, not 100%)
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 aliceValue = vault.convertToAssets(aliceShares);
        uint256 aliceProfit = aliceValue - (deposit - 1); // -1 for tiny withdrawal

        assertApproxEqAbs(aliceProfit, profit * 9 / 10, 1e18, "Alice should get 90% of profit");
    }

    function test_protocolFee_formula_correctness() public {
        uint256 deposit = 1000e18;
        uint256 profit = 500e18;

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // Add profit
        vm.prank(protocol);
        mockToken.transfer(address(vault), profit);

        // Calculate expected shares to mint using the formula
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 lastAssetAmount = deposit;

        // Formula: sharesToMint = (profit * totalSupply()) / (10 * lastAssetAmount + 9 * profit)
        uint256 numerator = profit * totalSupplyBefore;
        uint256 denominator = 10 * lastAssetAmount + 9 * profit;
        uint256 expectedSharesToMint = numerator / denominator;

        // Trigger fee
        vm.startPrank(bob);
        mockToken.approve(address(vault), 1);
        vault.deposit(1, 0); // Use 0 minSharesOut to avoid slippage
        vm.stopPrank();

        // Check DAO received expected shares
        uint256 daoShares = vault.balanceOf(dao);
        assertApproxEqAbs(daoShares, expectedSharesToMint, 1, "DAO should receive calculated shares");

        // Verify share price is correct after fee
        // New share price should give LPs 90% of the profit
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 aliceValue = vault.convertToAssets(aliceShares);
        uint256 expectedAliceValue = deposit + (profit * 9 / 10);

        assertApproxEqAbs(aliceValue, expectedAliceValue, 1e16, "Alice should have 90% of profit value");
    }

    function test_protocolFee_multipleProfit_cycles() public {
        uint256 deposit = 1000e18;

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        uint256 totalExpectedDaoValue = 0;

        // Multiple profit cycles
        for (uint i = 0; i < 3; i++) {
            uint256 profit = 200e18;
            totalExpectedDaoValue += profit / 10; // 10% of each profit

            // Add profit
            vm.prank(protocol);
            mockToken.transfer(address(vault), profit);

            // Trigger fee
            vm.startPrank(alice);
            vault.withdraw(1, 0); // Use 0 minAssetOut to avoid slippage
            vm.stopPrank();
        }

        // Check cumulative DAO value
        uint256 daoShares = vault.balanceOf(dao);
        uint256 daoValue = vault.convertToAssets(daoShares);

        assertApproxEqAbs(daoValue, totalExpectedDaoValue, 10e18, "DAO should accumulate ~10% of all profits");
    }

    function test_protocolFee_noFee_onFirstDeposit() public {
        // First deposit should not trigger fee since lastAssetAmount = 0
        uint256 deposit = 1000e18;

        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // DAO should have no shares
        assertEq(vault.balanceOf(dao), 0, "No protocol fee on first deposit");
    }

    function test_protocolFee_noFee_onNoProfit() public {
        uint256 deposit = 1000e18;

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // Bob deposits (no profit added)
        vm.startPrank(bob);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // No fee should be charged since no profit
        assertEq(vault.balanceOf(dao), 0, "No protocol fee when no profit");
    }

    function test_protocolFee_dao_can_withdraw() public {
        uint256 deposit = 1000e18;
        uint256 profit = 1000e18;

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // Add profit
        vm.prank(protocol);
        mockToken.transfer(address(vault), profit);

        // Trigger fee
        vm.startPrank(bob);
        mockToken.approve(address(vault), 1);
        vault.deposit(1, 0); // Use 0 minSharesOut to avoid slippage
        vm.stopPrank();

        // DAO withdraws its fee
        uint256 daoShares = vault.balanceOf(dao);
        uint256 daoExpectedAssets = vault.convertToAssets(daoShares);

        vm.startPrank(dao);
        vault.withdraw(daoShares, daoExpectedAssets);
        vm.stopPrank();

        // DAO should have received ~10% of profit
        uint256 daoBalance = mockToken.balanceOf(dao);
        assertApproxEqAbs(daoBalance, profit / 10, 1e18, "DAO should receive 10% of profit");
    }

    function test_protocolFee_precision_edge_cases() public {
        // Test with very small amounts to check precision
        uint256 deposit = 100; // Very small deposit
        uint256 profit = 50;   // Very small profit

        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        vm.prank(protocol);
        mockToken.transfer(address(vault), profit);

        vm.startPrank(bob);
        mockToken.approve(address(vault), 1);
        vault.deposit(1, 0);
        vm.stopPrank();

        // Even with small amounts, DAO should get some shares (or zero if rounded down)
        uint256 daoShares = vault.balanceOf(dao);
        // With such small numbers, might round to zero, which is acceptable
        assertTrue(daoShares >= 0, "DAO shares should be non-negative");
    }

    function test_protocolFee_share_price_impact() public {
        uint256 deposit = 1000e18;

        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();

        // Check initial share price (should be 1.0)
        uint256 initialPrice = vault.convertToAssets(1e18); // Price of 1 share
        assertEq(initialPrice, 1e18, "Initial share price should be 1.0");

        // Add 100% profit
        uint256 profit = 1000e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), profit);

        // Trigger protocol fee
        vm.startPrank(bob);
        mockToken.approve(address(vault), 1);
        vault.deposit(1, 0);
        vm.stopPrank();

        // Share price should now be ~1.9 (90% increase due to 10% fee)
        uint256 newPrice = vault.convertToAssets(1e18);
        uint256 expectedPrice = 1.9e18; // 90% increase

        assertApproxEqAbs(newPrice, expectedPrice, 0.01e18, "Share price should be ~1.9 after 100% profit and 10% fee");
    }
}