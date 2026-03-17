// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {SlimStake} from "../../src/SlimStake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens to deployer
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SlimStakeEndToEndTest is Test {
    SlimStake public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    uint256 constant WAD = 1e18;
    uint256 constant DEFAULT_REWARD_RATE = 11_574_074_074_074; // ~1 token per day per deposited token

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract
        staking = new SlimStake(depositToken, rewardToken);

        // Distribute tokens to test users
        depositToken.transfer(alice, 1000 * WAD);
        depositToken.transfer(bob, 1000 * WAD);
        depositToken.transfer(charlie, 1000 * WAD);

        // Fund staking contract with rewards
        rewardToken.transfer(address(staking), 10000 * WAD);

        // Approve staking contract
        vm.prank(alice);
        depositToken.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        depositToken.approve(address(staking), type(uint256).max);

        vm.prank(charlie);
        depositToken.approve(address(staking), type(uint256).max);
    }

    function test_ConstructorRejectsSameToken() public {
        vm.expectRevert("deposit and reward tokens must be different");
        new SlimStake(depositToken, depositToken);
    }

    function test_InitialState() public view {
        assertEq(address(staking.depositToken()), address(depositToken));
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertEq(staking.rewardPerDepositTokenPerSecond(), DEFAULT_REWARD_RATE);
        assertEq(staking.accumulatedRewardsPerDepositTokenWAD(), 0);
    }

    function test_SingleUserDepositAndWithdraw() public {
        uint256 depositAmount = 100 * WAD;

        // Alice deposits
        vm.prank(alice);
        staking.deposit(depositAmount);

        // Check balances
        assertEq(depositToken.balanceOf(alice), 900 * WAD);
        assertEq(depositToken.balanceOf(address(staking)), depositAmount);

        (uint256 debt, uint256 balance) = staking.deposits(alice);
        assertEq(balance, depositAmount);
        assertEq(debt, 0); // No accumulated rewards yet

        // Wait some time and check rewards
        vm.warp(block.timestamp + 1 days);

        // With 100 tokens deposited, 1 day passes
        // Reward = rate * time * depositAmount / totalDeposits
        // = 11_574_074_074_074 * 86400 * 100e18 / 100e18 = ~1 token
        uint256 expectedRewards = (DEFAULT_REWARD_RATE * 86400 * depositAmount) / depositAmount;
        uint256 actualRewards = staking.viewRewards(alice);

        // Allow for small rounding differences
        assertApproxEqRel(actualRewards, expectedRewards, 0.01e18); // 1% tolerance

        // Alice withdraws
        vm.prank(alice);
        staking.withdraw(depositAmount);

        // Check final balances
        assertEq(depositToken.balanceOf(alice), 1000 * WAD);
        (debt, balance) = staking.deposits(alice);
        assertEq(balance, 0);
    }

    function test_MultipleUsersEarnProportionalRewards() public {
        // Alice deposits 100 tokens
        vm.prank(alice);
        staking.deposit(100 * WAD);

        // Wait 1 day
        vm.warp(block.timestamp + 1 days);

        // Bob deposits 100 tokens (same as Alice)
        vm.prank(bob);
        staking.deposit(100 * WAD);

        // Wait another day
        vm.warp(block.timestamp + 1 days);

        // Day 1: Alice has 100 tokens, total = 100
        //        Alice earns: 100 * rate * 86400 / 100 = rate * 86400 = ~1 token
        // Day 2: Alice has 100 tokens, total = 200
        //        Alice earns: 100 * rate * 86400 / 200 = rate * 86400 / 2 = ~0.5 tokens
        // Total: ~1.5 tokens
        uint256 baseReward = DEFAULT_REWARD_RATE * 86400;
        uint256 aliceRewards = staking.viewRewards(alice);
        assertApproxEqRel(aliceRewards, baseReward + baseReward / 2, 0.01e18);

        // Bob: Day 2 only, with 100 tokens out of 200 total
        //      Bob earns: 100 * rate * 86400 / 200 = ~0.5 tokens
        uint256 bobRewards = staking.viewRewards(bob);
        assertApproxEqRel(bobRewards, baseReward / 2, 0.01e18);
    }

    function test_DepositClaimsExistingRewards() public {
        // Alice deposits
        vm.prank(alice);
        staking.deposit(100 * WAD);

        uint256 aliceRewardBalanceBefore = rewardToken.balanceOf(alice);

        // Wait 1 day
        vm.warp(block.timestamp + 1 days);

        // Alice deposits again (should claim rewards)
        vm.prank(alice);
        staking.deposit(50 * WAD);

        // Check that rewards were claimed
        // 100 tokens deposited, 1 day, total deposits = 100
        // Rewards = 100 * rate * 86400 / 100 = rate * 86400 = ~1 token
        uint256 aliceRewardBalanceAfter = rewardToken.balanceOf(alice);
        uint256 rewardsClaimed = aliceRewardBalanceAfter - aliceRewardBalanceBefore;

        assertApproxEqRel(rewardsClaimed, DEFAULT_REWARD_RATE * 86400, 0.01e18);

        // Pending rewards should now be 0
        assertEq(staking.viewRewards(alice), 0);
    }

    function test_WithdrawClaimsRewards() public {
        // Alice deposits
        vm.prank(alice);
        staking.deposit(100 * WAD);

        uint256 aliceRewardBalanceBefore = rewardToken.balanceOf(alice);

        // Wait 1 day
        vm.warp(block.timestamp + 1 days);

        // Alice withdraws half
        vm.prank(alice);
        staking.withdraw(50 * WAD);

        // Check that rewards were claimed
        // 100 tokens deposited, 1 day, total deposits = 100
        // Rewards = rate * 86400
        uint256 aliceRewardBalanceAfter = rewardToken.balanceOf(alice);
        uint256 rewardsClaimed = aliceRewardBalanceAfter - aliceRewardBalanceBefore;

        assertApproxEqRel(rewardsClaimed, DEFAULT_REWARD_RATE * 86400, 0.01e18);

        // Pending rewards should now be 0
        assertEq(staking.viewRewards(alice), 0);
    }

    function test_RewardRateChange() public {
        // Alice deposits
        vm.prank(alice);
        staking.deposit(100 * WAD);

        // Wait 1 day with default rate
        vm.warp(block.timestamp + 1 days);

        // Owner doubles the reward rate
        staking.setRewardRate(DEFAULT_REWARD_RATE * 2);

        // Wait another day with doubled rate
        vm.warp(block.timestamp + 1 days);

        // Alice: Day 1 at 1x rate + Day 2 at 2x rate
        // = rate * 86400 + (rate * 2) * 86400 = 3 * rate * 86400
        uint256 aliceRewards = staking.viewRewards(alice);
        assertApproxEqRel(aliceRewards, 3 * DEFAULT_REWARD_RATE * 86400, 0.01e18);
    }

    function test_OnlyOwnerCanSetRewardRate() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.setRewardRate(1000);
    }

    function test_CannotWithdrawMoreThanBalance() public {
        vm.prank(alice);
        staking.deposit(100 * WAD);

        vm.prank(alice);
        vm.expectRevert("withdraw amount exceeds balance");
        staking.withdraw(101 * WAD);
    }

    function test_RewardsAccumulateAccuratelyOverTime() public {
        uint256 depositAmount = 100 * WAD;

        vm.prank(alice);
        staking.deposit(depositAmount);

        // Test at various time intervals
        uint256[] memory timeIntervals = new uint256[](5);
        timeIntervals[0] = 1 hours;
        timeIntervals[1] = 1 days;
        timeIntervals[2] = 7 days;
        timeIntervals[3] = 30 days;
        timeIntervals[4] = 365 days;

        for (uint256 i = 0; i < timeIntervals.length; i++) {
            vm.warp(block.timestamp + timeIntervals[i]);

            // Rewards = balance * rate * time / totalDeposits
            // With only Alice depositing, totalDeposits = depositAmount
            uint256 expectedRewards = DEFAULT_REWARD_RATE * timeIntervals[i];
            uint256 actualRewards = staking.viewRewards(alice);

            assertApproxEqRel(actualRewards, expectedRewards, 0.01e18);

            // Reset for next iteration
            vm.warp(block.timestamp - timeIntervals[i]);
        }
    }

    function test_NoRewardsOnSameBlock() public {
        vm.prank(alice);
        staking.deposit(100 * WAD);

        // Check rewards immediately (same block)
        uint256 rewards = staking.viewRewards(alice);
        assertEq(rewards, 0);
    }

    function test_MultipleDepositsAndWithdrawals() public {
        // Alice makes multiple deposits
        vm.startPrank(alice);

        staking.deposit(50 * WAD);
        vm.warp(block.timestamp + 1 days);

        staking.deposit(50 * WAD);
        vm.warp(block.timestamp + 1 days);

        staking.deposit(100 * WAD);
        vm.warp(block.timestamp + 1 days);

        // Partial withdrawals
        staking.withdraw(50 * WAD);
        vm.warp(block.timestamp + 1 days);

        staking.withdraw(50 * WAD);

        vm.stopPrank();

        // Verify final state
        (, uint256 balance) = staking.deposits(alice);
        assertEq(balance, 100 * WAD);
    }

    function test_ThreeUsersComplexScenario() public {
        uint256 baseReward = DEFAULT_REWARD_RATE * 86400;

        // Day 0: Alice deposits 100
        vm.prank(alice);
        staking.deposit(100 * WAD);

        // Day 1: Bob deposits 200
        vm.warp(block.timestamp + 1 days);
        vm.prank(bob);
        staking.deposit(200 * WAD);

        // Day 2: Charlie deposits 300
        vm.warp(block.timestamp + 1 days);
        vm.prank(charlie);
        staking.deposit(300 * WAD);

        // Day 3: Check everyone's rewards
        vm.warp(block.timestamp + 1 days);

        // Alice: Day 1: 100 * rate * 86400 / 100 = baseReward
        //        Day 2: 100 * rate * 86400 / 300 = baseReward / 3
        //        Day 3: 100 * rate * 86400 / 600 = baseReward / 6
        //        Total: baseReward * (1 + 1/3 + 1/6) = baseReward * 1.5
        assertApproxEqRel(staking.viewRewards(alice), baseReward + baseReward / 3 + baseReward / 6, 0.02e18);

        // Bob:   Day 2: 200 * rate * 86400 / 300 = baseReward * 2/3
        //        Day 3: 200 * rate * 86400 / 600 = baseReward / 3
        //        Total: baseReward * (2/3 + 1/3) = baseReward
        assertApproxEqRel(staking.viewRewards(bob), baseReward * 2 / 3 + baseReward / 3, 0.02e18);

        // Charlie: Day 3: 300 * rate * 86400 / 600 = baseReward / 2
        assertApproxEqRel(staking.viewRewards(charlie), baseReward / 2, 0.02e18);
    }

    function test_EmitDepositEvent() public {
        vm.expectEmit(true, false, false, true);
        emit SlimStake.Deposit(alice, 100 * WAD);

        vm.prank(alice);
        staking.deposit(100 * WAD);
    }

    function test_EmitWithdrawEvent() public {
        vm.prank(alice);
        staking.deposit(100 * WAD);

        vm.expectEmit(true, false, false, true);
        emit SlimStake.Withdraw(alice, 50 * WAD);

        vm.prank(alice);
        staking.withdraw(50 * WAD);
    }

    function test_EmitSetRewardRateEvent() public {
        uint256 newRate = 20_000_000_000_000;

        vm.expectEmit(false, false, false, true);
        emit SlimStake.SetRewardRate(block.timestamp, newRate);

        staking.setRewardRate(newRate);
    }

    function test_RewardDepletionHandling() public {
        // Create new staking contract with limited rewards
        SlimStake limitedStaking = new SlimStake(depositToken, rewardToken);
        rewardToken.transfer(address(limitedStaking), 10 * WAD); // Only 10 tokens

        vm.prank(alice);
        depositToken.approve(address(limitedStaking), type(uint256).max);

        // Alice deposits
        vm.prank(alice);
        limitedStaking.deposit(100 * WAD);

        // Wait long enough to earn more than 10 tokens
        vm.warp(block.timestamp + 30 days);

        // Calculate expected rewards (should be way more than 10 tokens)
        uint256 expectedRewards = DEFAULT_REWARD_RATE * (30 days);
        assertGt(expectedRewards, 10 * WAD);

        // Withdraw should only give available rewards
        uint256 balanceBefore = rewardToken.balanceOf(alice);
        vm.prank(alice);
        limitedStaking.withdraw(100 * WAD);

        uint256 balanceAfter = rewardToken.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, 10 * WAD); // Only got what was available
    }
}
