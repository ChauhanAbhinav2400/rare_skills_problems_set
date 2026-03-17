// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {SlimStake} from "../../src/SlimStake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

// Helper contract to expose internal _transferRewards function
contract SlimStakeHarness is SlimStake {
    constructor(IERC20 _depositToken, IERC20 _rewardToken) SlimStake(_depositToken, _rewardToken) {}

    // Expose internal function for testing
    function exposed_transferRewards(address receiver, uint256 amount) external {
        _transferRewards(receiver, amount);
    }
}

contract SlimStakeTransferRewardsTest is Test {
    SlimStakeHarness public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    address public alice;
    address public bob;

    uint256 constant WAD = 1e18;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract with harness
        staking = new SlimStakeHarness(depositToken, rewardToken);

        // Fund staking contract with 100 reward tokens
        rewardToken.transfer(address(staking), 100 * WAD);
    }

    function test_TransferRewardsZeroAmount() public {
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(staking));

        // Transfer 0 tokens should not revert
        staking.exposed_transferRewards(alice, 0);

        // Balances should remain unchanged
        assertEq(rewardToken.balanceOf(alice), aliceBalanceBefore);
        assertEq(rewardToken.balanceOf(address(staking)), contractBalanceBefore);
    }

    function test_TransferRewardsNormalAmount() public {
        uint256 transferAmount = 50 * WAD;
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(staking));

        // Transfer normal amount (less than contract balance)
        staking.exposed_transferRewards(alice, transferAmount);

        // Verify transfer occurred
        assertEq(rewardToken.balanceOf(alice), aliceBalanceBefore + transferAmount);
        assertEq(rewardToken.balanceOf(address(staking)), contractBalanceBefore - transferAmount);
    }

    function test_TransferRewardsExactBalance() public {
        uint256 contractBalance = rewardToken.balanceOf(address(staking));
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);

        // Transfer exact balance
        staking.exposed_transferRewards(alice, contractBalance);

        // Verify all tokens transferred
        assertEq(rewardToken.balanceOf(alice), aliceBalanceBefore + contractBalance);
        assertEq(rewardToken.balanceOf(address(staking)), 0);
    }

    function test_TransferRewardsMoreThanBalance() public {
        uint256 contractBalance = rewardToken.balanceOf(address(staking));
        uint256 requestedAmount = contractBalance + 50 * WAD; // Request more than available
        uint256 aliceBalanceBefore = rewardToken.balanceOf(alice);

        // Transfer more than balance should only transfer available balance
        staking.exposed_transferRewards(alice, requestedAmount);

        // Should only transfer what's available (100 tokens)
        assertEq(rewardToken.balanceOf(alice), aliceBalanceBefore + contractBalance);
        assertEq(rewardToken.balanceOf(address(staking)), 0);
    }

    function test_TransferRewardsWhenBalanceIsZero() public {
        // First drain the contract
        uint256 contractBalance = rewardToken.balanceOf(address(staking));
        staking.exposed_transferRewards(alice, contractBalance);

        // Verify contract is empty
        assertEq(rewardToken.balanceOf(address(staking)), 0);

        uint256 bobBalanceBefore = rewardToken.balanceOf(bob);

        // Try to transfer when balance is zero
        staking.exposed_transferRewards(bob, 100 * WAD);

        // Bob should receive nothing (no revert)
        assertEq(rewardToken.balanceOf(bob), bobBalanceBefore);
    }

    function test_TransferRewardsToMultipleReceivers() public {
        uint256 amount1 = 30 * WAD;
        uint256 amount2 = 40 * WAD;

        // Transfer to Alice
        staking.exposed_transferRewards(alice, amount1);
        assertEq(rewardToken.balanceOf(alice), amount1);

        // Transfer to Bob
        staking.exposed_transferRewards(bob, amount2);
        assertEq(rewardToken.balanceOf(bob), amount2);

        // Contract should have remaining balance
        assertEq(rewardToken.balanceOf(address(staking)), 100 * WAD - amount1 - amount2);
    }

    function test_TransferRewardsDoesNotRevert() public {
        // This test verifies the function never reverts under any circumstances
        // as per the contract documentation

        // Case 1: Normal transfer - should not revert
        staking.exposed_transferRewards(alice, 10 * WAD);

        // Case 2: Zero transfer - should not revert
        staking.exposed_transferRewards(alice, 0);

        // Case 3: Transfer more than balance - should not revert
        staking.exposed_transferRewards(alice, 1000 * WAD);

        // Case 4: Transfer when balance is zero - should not revert
        staking.exposed_transferRewards(bob, 100 * WAD);
    }

    function testFuzz_TransferRewardsNeverReverts(address receiver, uint256 amount) public {
        // Assume valid receiver address
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(staking));

        // This should never revert regardless of amount
        staking.exposed_transferRewards(receiver, amount);

        // Verify receiver got min(amount, contractBalance)
        uint256 receiverBalance = rewardToken.balanceOf(receiver);
        assertTrue(receiverBalance <= 100 * WAD); // Can't exceed initial funding
    }
}
