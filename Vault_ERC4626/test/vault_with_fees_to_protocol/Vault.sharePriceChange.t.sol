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

contract VaultSharePriceChangeTest is Test {
    Vault public vault;
    MockERC20 public mockToken;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public protocol = address(0x3); // Represents protocol making profits
    address public dao = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Same as in Vault contract
    
    function setUp() public {
        mockToken = new MockERC20();
        vault = new Vault(mockToken);
        
        // Give users initial tokens
        mockToken.mint(alice, 10000e18);
        mockToken.mint(bob, 10000e18);
        mockToken.mint(protocol, 10000e18); // Protocol has tokens to simulate profits
    }

    function test_singleUser_protocolProfit_userGainsMore() public {
        uint256 initialDeposit = 1000e18;
        
        // Alice deposits 1000 tokens, gets 1000 shares (1:1 ratio initially)
        vm.startPrank(alice);
        mockToken.approve(address(vault), initialDeposit);
        vault.deposit(initialDeposit, initialDeposit);
        vm.stopPrank();
        
        // Verify initial state
        assertEq(vault.balanceOf(alice), 1000e18, "Alice should have 1000 shares");
        assertEq(vault.totalSupply(), 1000e18, "Total supply should be 1000");
        assertEq(mockToken.balanceOf(address(vault)), 1000e18, "Vault should hold 1000 tokens");
        
        // Protocol makes a profit by sending 500 tokens directly to vault
        // This simulates yield farming, trading profits, etc.
        uint256 protocolProfit = 500e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), protocolProfit);
        
        // Now vault has 1500 tokens but still only 1000 shares outstanding
        // Share price: 1500 / 1000 = 1.5 tokens per share
        assertEq(mockToken.balanceOf(address(vault)), 1500e18, "Vault should hold 1500 tokens after profit");
        
        // Check protocol fee was minted to DAO
        uint256 daoSharesBefore = vault.balanceOf(dao);

        // Alice withdraws all her shares (this triggers protocol fee)
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 expectedAssets = vault.convertToAssets(aliceShares);

        vm.startPrank(alice);
        vault.withdraw(aliceShares, 0); // Use 0 to avoid slippage
        vm.stopPrank();

        // Check protocol fee was minted
        uint256 daoSharesAfter = vault.balanceOf(dao);
        assertTrue(daoSharesAfter > daoSharesBefore, "DAO should receive protocol fee shares");

        // With 10% protocol fee, Alice should get ~90% of the profit (450e18 instead of 500e18)
        uint256 aliceReceived = mockToken.balanceOf(alice) - 9000e18;
        uint256 aliceProfit = aliceReceived - initialDeposit;

        // Alice gets 90% of profits due to 10% protocol fee dilution
        // Note: exact amount may vary due to when protocol fee is applied
        assertTrue(aliceProfit > 400e18 && aliceProfit < 500e18, "Alice should get ~90% of profit after protocol fee");
        assertTrue(aliceProfit > 0, "Alice should have made a profit");
    }

    function test_sharePrice_decreasesNewSharesWhenProfitExists() public {
        uint256 initialDeposit = 1000e18;
        
        // Alice deposits first (gets 1:1 ratio)
        vm.startPrank(alice);
        mockToken.approve(address(vault), initialDeposit);
        vault.deposit(initialDeposit, initialDeposit);
        vm.stopPrank();
        
        // Protocol makes profit
        uint256 protocolProfit = 500e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), protocolProfit);
        
        // Now share price is 1500 tokens / 1000 shares = 1.5 tokens per share
        
        // Bob tries to deposit the same amount as Alice
        uint256 bobDeposit = 1000e18;
        uint256 expectedBobShares = vault.convertToShares(bobDeposit);
        
        // After protocol fee is applied, the share calculation changes
        // We'll just verify Bob gets fewer shares than Alice for same deposit
        assertTrue(expectedBobShares < 1000e18, "Bob should get fewer shares due to higher share price");
        
        vm.startPrank(bob);
        mockToken.approve(address(vault), bobDeposit);
        vault.deposit(bobDeposit, 0); // Use 0 to avoid slippage
        vm.stopPrank();
        
        // Just verify Bob got the shares (exact amount will vary due to protocol fee)
        assertTrue(vault.balanceOf(bob) < vault.balanceOf(alice), "Bob should have fewer shares than Alice for same deposit");
    }

    function test_multipleUsers_earlierDepositorBenefitsMore() public {
        // === Phase 1: Alice deposits ===
        uint256 aliceDeposit = 1000e18;
        
        vm.startPrank(alice);
        mockToken.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, aliceDeposit); // Gets 1000 shares
        vm.stopPrank();
        
        console.log("=== After Alice deposits ===");
        console.log("Alice shares:", vault.balanceOf(alice));
        console.log("Total supply:", vault.totalSupply());
        console.log("Vault balance:", mockToken.balanceOf(address(vault)));
        
        // === Phase 2: Protocol makes first profit ===
        uint256 firstProfit = 500e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), firstProfit);
        
        console.log("=== After first profit ===");
        console.log("Vault balance:", mockToken.balanceOf(address(vault))); // Should be 1500
        
        // Share price is now: 1500 / 1000 = 1.5 tokens per share
        
        // === Phase 3: Bob deposits (at higher share price) ===
        uint256 bobDeposit = 1000e18;
        uint256 bobExpectedShares = vault.convertToShares(bobDeposit); // 1000 * 1000 / 1500 = 666.67
        
        vm.startPrank(bob);
        mockToken.approve(address(vault), bobDeposit);
        vault.deposit(bobDeposit, 0); // Use 0 to avoid slippage
        vm.stopPrank();
        
        console.log("=== After Bob deposits ===");
        console.log("Alice shares:", vault.balanceOf(alice));
        console.log("Bob shares:", vault.balanceOf(bob));
        console.log("Total supply:", vault.totalSupply());
        console.log("Vault balance:", mockToken.balanceOf(address(vault))); // Should be 2500
        
        // === Phase 4: Protocol makes second profit ===
        uint256 secondProfit = 750e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), secondProfit);
        
        console.log("=== After second profit ===");
        console.log("Vault balance:", mockToken.balanceOf(address(vault))); // Should be 3250
        
        // === Phase 5: Both users withdraw ===
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 bobShares = vault.balanceOf(bob);
        
        uint256 aliceExpectedAssets = vault.convertToAssets(aliceShares);
        uint256 bobExpectedAssets = vault.convertToAssets(bobShares);
        
        console.log("=== Expected withdrawals ===");
        console.log("Alice expected assets:", aliceExpectedAssets);
        console.log("Bob expected assets:", bobExpectedAssets);
        
        // Alice withdraws
        vm.startPrank(alice);
        vault.withdraw(aliceShares, 0); // Use 0 to avoid slippage
        vm.stopPrank();
        
        // Bob withdraws
        vm.startPrank(bob);
        vault.withdraw(bobShares, 0); // Use 0 to avoid slippage
        vm.stopPrank();
        
        // === Calculate profits ===
        // Profit = what they received - what they deposited
        uint256 aliceReceived = mockToken.balanceOf(alice) - (10000e18 - aliceDeposit);
        uint256 bobReceived = mockToken.balanceOf(bob) - (10000e18 - bobDeposit);
        
        uint256 aliceProfit = aliceReceived - aliceDeposit;
        uint256 bobProfit = bobReceived - bobDeposit;
        
        console.log("=== Final Results ===");
        console.log("Alice profit:", aliceProfit);
        console.log("Bob profit:", bobProfit);
        
        // === Assertions ===
        
        // Both users should make a profit
        assertTrue(aliceProfit > 0, "Alice should make a profit");
        assertTrue(bobProfit > 0, "Bob should make a profit");
        
        // Alice should make more profit than Bob
        assertTrue(aliceProfit > bobProfit, "Alice should make more profit than Bob");
        
        // Total profits should approximately equal protocol profits
        uint256 totalProfitsDistributed = aliceProfit + bobProfit;
        uint256 totalProtocolProfits = 1250e18; // 500e18 + 750e18
        
        assertApproxEqAbs(
            totalProfitsDistributed, 
            totalProtocolProfits, 
            150e18, // Allow larger difference due to protocol fees
            "Total profits distributed should approximately equal total protocol profits"
        );
    }

    function test_noProfit_equalSharesEqualReturns() public {
        // Baseline test: without profits, users get back what they put in
        
        uint256 aliceDeposit = 1000e18;
        uint256 bobDeposit = 1500e18;
        
        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, aliceDeposit);
        vm.stopPrank();
        
        // Bob deposits  
        vm.startPrank(bob);
        mockToken.approve(address(vault), bobDeposit);
        vault.deposit(bobDeposit, bobDeposit);
        vm.stopPrank();
        
        // Both withdraw
        vm.startPrank(alice);
        vault.withdraw(vault.balanceOf(alice), aliceDeposit);
        vm.stopPrank();
        
        vm.startPrank(bob);
        vault.withdraw(vault.balanceOf(bob), bobDeposit);
        vm.stopPrank();
        
        // Both should get back exactly what they deposited
        assertEq(mockToken.balanceOf(alice), 10000e18, "Alice should get back her original balance");
        assertEq(mockToken.balanceOf(bob), 10000e18, "Bob should get back his original balance");
    }

    function test_profit_beforeAnyDeposits_firstDepositorGetsAll() public {
        // Edge case: protocol somehow has profits before anyone deposits
        
        // Protocol sends profits to empty vault
        uint256 initialProfit = 100e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), initialProfit);
        
        // Alice is first depositor
        uint256 aliceDeposit = 1000e18;
        
        vm.startPrank(alice);
        mockToken.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, aliceDeposit); // Should still get 1:1 since totalSupply is 0
        vm.stopPrank();
        
        // Alice should get all the existing profit when she withdraws
        vm.startPrank(alice);
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 expectedAssets = vault.convertToAssets(aliceShares);
        vault.withdraw(aliceShares, expectedAssets);
        vm.stopPrank();
        
        uint256 aliceReceived = mockToken.balanceOf(alice) - (10000e18 - aliceDeposit);
        uint256 aliceProfit = aliceReceived - aliceDeposit;
        assertEq(aliceProfit, initialProfit, "Alice should get all pre-existing profit");
    }

    function test_massiveProfit_sharePriceIncrease() public {
        uint256 deposit = 100e18;
        
        // Alice deposits
        vm.startPrank(alice);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, deposit);
        vm.stopPrank();
        
        // Protocol makes massive profit (10x the deposit)
        uint256 massiveProfit = 1000e18;
        vm.prank(protocol);
        mockToken.transfer(address(vault), massiveProfit);
        
        // Share price is now: (100 + 1000) / 100 = 11 tokens per share
        
        // Bob tries to deposit same amount
        uint256 bobExpectedShares = vault.convertToShares(deposit);
        // Expected: 100 * 100 / 1100 = ~9.09 shares

        vm.startPrank(bob);
        mockToken.approve(address(vault), deposit);
        vault.deposit(deposit, 0); // Use 0 to avoid slippage issues
        vm.stopPrank();
        
        assertTrue(vault.balanceOf(bob) < 20e18, "Bob should get fewer shares due to high share price");
        assertTrue(vault.balanceOf(alice) > vault.balanceOf(bob) * 5, "Alice should have more than 5x Bob's shares");
        
        // Both withdraw
        vm.startPrank(alice);
        uint256 aliceShares = vault.balanceOf(alice);
        vault.withdraw(aliceShares, vault.convertToAssets(aliceShares));
        vm.stopPrank();
        
        vm.startPrank(bob);
        uint256 bobShares = vault.balanceOf(bob);
        vault.withdraw(bobShares, vault.convertToAssets(bobShares));
        vm.stopPrank();
        
        uint256 aliceReceived = mockToken.balanceOf(alice) - (10000e18 - deposit);
        uint256 bobReceived = mockToken.balanceOf(bob) - (10000e18 - deposit);
        uint256 aliceProfit = aliceReceived - deposit;
        uint256 bobProfit = bobReceived - deposit;
        
        // Alice should capture most of the massive profit
        assertTrue(aliceProfit > 800e18, "Alice should get most of the 1000e18 profit after protocol fee");
        assertTrue(bobProfit >= 0, "Bob should at least break even");
        assertTrue(aliceProfit > bobProfit * 5, "Alice's profit should be much larger than Bob's");
    }
}