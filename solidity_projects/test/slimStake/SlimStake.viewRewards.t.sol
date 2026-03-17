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

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Helper contract to expose internal functions for state manipulation
contract SlimStakeHarness is SlimStake {
    constructor(IERC20 _depositToken, IERC20 _rewardToken) SlimStake(_depositToken, _rewardToken) {}

    // Expose _updatePool to manually trigger updates
    function exposed_updatePool() external {
        _updatePool();
    }
}

contract SlimStakeViewRewardsTest is Test {
    SlimStakeHarness public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant WAD = 1e18;
    uint256 constant DEFAULT_REWARD_RATE = 11_574_074_074_074;

    // Storage slot locations
    bytes32 constant REWARD_RATE_SLOT = bytes32(uint256(4));
    bytes32 constant ACCUMULATED_REWARDS_SLOT = bytes32(uint256(5));
    bytes32 constant LAST_UPDATE_TIME_SLOT = bytes32(uint256(6));

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract with harness
        staking = new SlimStakeHarness(depositToken, rewardToken);
    }

    // ===== Helper Functions =====

    function setLastUpdateTime(uint40 timestamp) internal {
        vm.store(address(staking), LAST_UPDATE_TIME_SLOT, bytes32(uint256(timestamp)));
    }

    function setRewardRate(uint256 rate) internal {
        vm.store(address(staking), REWARD_RATE_SLOT, bytes32(rate));
    }

    function setAccumulatedRewards(uint256 amount) internal {
        vm.store(address(staking), ACCUMULATED_REWARDS_SLOT, bytes32(amount));
    }

    function setDepositTokenBalance(uint256 amount) internal {
        depositToken.mint(address(staking), amount);
    }

    function setUserDeposit(address user, uint256 balance, uint256 debt) internal {
        // deposits mapping is at slot 7
        // DepositInfo has two fields: debt (slot 0) and balance (slot 1)
        bytes32 depositSlot = keccak256(abi.encode(user, uint256(7)));

        vm.store(address(staking), depositSlot, bytes32(debt)); // debt
        vm.store(address(staking), bytes32(uint256(depositSlot) + 1), bytes32(balance)); // balance
    }

    // ===== Basic Cases =====

    function test_ViewRewardsReturnsZeroForNoDeposit() public view {
        uint256 rewards = staking.viewRewards(alice);
        assertEq(rewards, 0);
    }

    function test_ViewRewardsReturnsZeroImmediatelyAfterDeposit() public {
        // Set up a fresh deposit where debt == accumulatedRewards
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(5 * WAD);
        setLastUpdateTime(uint40(block.timestamp));

        uint256 balance = 100 * WAD;
        uint256 debt = balance * 5 * WAD / WAD; // debt = balance * accRewards / WAD

        setUserDeposit(alice, balance, debt);

        uint256 rewards = staking.viewRewards(alice);
        assertEq(rewards, 0);
    }

    // ===== Accumulated but Not Updated Cases =====

    function test_ViewRewardsWhenAccumulatedButNotUpdated() public {
        // Setup: User deposited at time T, now it's T+1day, but _updatePool hasn't been called
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // User deposited when accumulated was 0, so debt = 0
        setUserDeposit(alice, 100 * WAD, 0);

        // Warp forward 1 day WITHOUT calling _updatePool
        vm.warp(initialTime + 1 days);

        // viewRewards should include pending rewards
        uint256 rewards = staking.viewRewards(alice);

        // Expected: rate * 1 day (since accumulatedRewards is still 0, but view includes pending)
        uint256 expectedRewards = DEFAULT_REWARD_RATE * 1 days;
        assertEq(rewards, expectedRewards);
    }

    function test_ViewRewardsMultipleCallsWhenNotUpdated() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        vm.warp(initialTime + 1 days);

        // Call viewRewards multiple times in same block
        uint256 rewards1 = staking.viewRewards(alice);
        uint256 rewards2 = staking.viewRewards(alice);
        uint256 rewards3 = staking.viewRewards(alice);

        // All should return the same value
        assertEq(rewards1, rewards2);
        assertEq(rewards2, rewards3);
    }

    function test_ViewRewardsIncreaseOverTimeWhenNotUpdated() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // Check at 1 hour
        vm.warp(initialTime + 1 hours);
        uint256 rewardsAt1Hour = staking.viewRewards(alice);

        // Check at 1 day
        vm.warp(initialTime + 1 days);
        uint256 rewardsAt1Day = staking.viewRewards(alice);

        // Check at 7 days
        vm.warp(initialTime + 7 days);
        uint256 rewardsAt7Days = staking.viewRewards(alice);

        // Rewards should increase over time
        assertGt(rewardsAt1Day, rewardsAt1Hour);
        assertGt(rewardsAt7Days, rewardsAt1Day);

        // Verify specific values
        assertEq(rewardsAt1Hour, DEFAULT_REWARD_RATE * 1 hours);
        assertEq(rewardsAt1Day, DEFAULT_REWARD_RATE * 1 days);
        assertEq(rewardsAt7Days, DEFAULT_REWARD_RATE * 7 days);
    }

    // ===== After Update Cases =====

    function test_ViewRewardsRightAfterUpdate() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // Warp forward and call _updatePool
        vm.warp(initialTime + 1 days);
        staking.exposed_updatePool();

        // View rewards in same block as update
        uint256 rewards = staking.viewRewards(alice);

        // Expected: rate * 1 day (accumulated was updated, no additional pending)
        uint256 expectedRewards = DEFAULT_REWARD_RATE * 1 days;
        assertEq(rewards, expectedRewards);
    }

    function test_ViewRewardsAfterUpdateThenMoreTimeElapses() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // First update after 1 day
        vm.warp(initialTime + 1 days);
        staking.exposed_updatePool();

        uint256 rewardsAfterFirstUpdate = staking.viewRewards(alice);

        // More time passes WITHOUT update
        vm.warp(initialTime + 2 days);

        uint256 rewardsAfterMoreTime = staking.viewRewards(alice);

        // Should have accumulated more rewards
        assertGt(rewardsAfterMoreTime, rewardsAfterFirstUpdate);

        // Verify values
        assertEq(rewardsAfterFirstUpdate, DEFAULT_REWARD_RATE * 1 days);
        assertEq(rewardsAfterMoreTime, DEFAULT_REWARD_RATE * 2 days);
    }

    function test_ViewRewardsMultipleUpdates() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // Update after 1 hour
        vm.warp(initialTime + 1 hours);
        staking.exposed_updatePool();
        uint256 rewards1 = staking.viewRewards(alice);

        // Update after 2 hours (total)
        vm.warp(initialTime + 2 hours);
        staking.exposed_updatePool();
        uint256 rewards2 = staking.viewRewards(alice);

        // Update after 3 hours (total)
        vm.warp(initialTime + 3 hours);
        staking.exposed_updatePool();
        uint256 rewards3 = staking.viewRewards(alice);

        assertEq(rewards1, DEFAULT_REWARD_RATE * 1 hours);
        assertEq(rewards2, DEFAULT_REWARD_RATE * 2 hours);
        assertEq(rewards3, DEFAULT_REWARD_RATE * 3 hours);
    }

    // ===== Multiple Users =====

    function test_ViewRewardsMultipleUsers() public {
        setDepositTokenBalance(300 * WAD); // Total deposits
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Alice: 100 tokens, debt = 0
        setUserDeposit(alice, 100 * WAD, 0);

        // Bob: 200 tokens, debt = 0
        setUserDeposit(bob, 200 * WAD, 0);

        vm.warp(initialTime + 1 days);

        uint256 aliceRewards = staking.viewRewards(alice);
        uint256 bobRewards = staking.viewRewards(bob);

        // With 300 total deposits:
        // Alice (100): 100 * rate * 86400 / 300 = rate * 86400 / 3
        // Bob (200): 200 * rate * 86400 / 300 = rate * 86400 * 2 / 3
        uint256 expectedAlice = (DEFAULT_REWARD_RATE * 1 days) / 3;
        uint256 expectedBob = (DEFAULT_REWARD_RATE * 1 days * 2) / 3;

        assertEq(aliceRewards, expectedAlice);
        assertEq(bobRewards, expectedBob);

        // Bob should have 2x Alice's rewards
        assertEq(bobRewards, aliceRewards * 2);
    }

    function test_ViewRewardsForUserWithNoDeposit() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Alice has deposit
        setUserDeposit(alice, 100 * WAD, 0);

        // Bob has no deposit
        // (no need to set anything for Bob)

        vm.warp(initialTime + 1 days);

        uint256 bobRewards = staking.viewRewards(bob);
        assertEq(bobRewards, 0);
    }

    // ===== Different Balances and Debts =====

    function test_ViewRewardsWithExistingAccumulated() public {
        setDepositTokenBalance(100 * WAD);

        // Start with some accumulated rewards already
        uint256 initialAccumulated = 10 * WAD;
        setAccumulatedRewards(initialAccumulated);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // User deposited when accumulated was 10, so debt = 100 * 10 / 1 = 1000
        uint256 debt = 100 * WAD * initialAccumulated / WAD;
        setUserDeposit(alice, 100 * WAD, debt);

        // Time passes
        vm.warp(initialTime + 1 days);

        // Expected: New rewards only (not the initial accumulated since debt cancels that out)
        uint256 rewards = staking.viewRewards(alice);
        uint256 expectedNewRewards = DEFAULT_REWARD_RATE * 1 days;

        assertEq(rewards, expectedNewRewards);
    }

    function test_ViewRewardsWithPartialDebt() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp + 1000;
        vm.warp(initialTime);
        setLastUpdateTime(uint40(initialTime));

        // User has some debt (simulating they already claimed some rewards)
        // debt < balance * accumulated, so they should still have rewards
        setUserDeposit(alice, 100 * WAD, 50 * WAD);

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        // accumulatedRewards = 0 + (rate * 86400 * WAD / 100e18)
        // accRewards = 100e18 * accumulatedRewards / WAD
        // rewards = accRewards - debt
        uint256 accumulatedRewardsPerToken = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 accRewards = 100 * WAD * accumulatedRewardsPerToken / WAD;

        // Calculate expected, handling case where debt might exceed
        uint256 expectedRewards = accRewards > 50 * WAD ? accRewards - 50 * WAD : 0;

        assertEq(rewards, expectedRewards);
    }

    function test_ViewRewardsWhenDebtExceedsAccRewards() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Set debt higher than possible accumulated rewards
        // This shouldn't happen in normal operation, but test the safety
        setUserDeposit(alice, 100 * WAD, 1000 * WAD);

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        // Should return 0 (not revert)
        assertEq(rewards, 0);
    }

    // ===== Zero Cases =====

    function test_ViewRewardsWhenNoTimeElapsed() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 currentTime = block.timestamp;
        setLastUpdateTime(uint40(currentTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // Don't warp - same block
        uint256 rewards = staking.viewRewards(alice);

        assertEq(rewards, 0);
    }

    function test_ViewRewardsWhenNoDepositsInContract() public {
        // No deposits in contract (totalDeposits = 0)
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // User somehow has a balance but no deposits in contract
        setUserDeposit(alice, 100 * WAD, 0);

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        // Should return 0 (increase is 0 when totalDeposits = 0)
        assertEq(rewards, 0);
    }

    function test_ViewRewardsWithZeroRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);
        setRewardRate(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        assertEq(rewards, 0);
    }

    // ===== Edge Cases =====

    function test_ViewRewardsWithVerySmallBalance() public {
        setDepositTokenBalance(1); // 1 wei total
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 1, 0); // 1 wei balance

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        // With 1 wei deposited: rate * 86400 * WAD / 1
        uint256 expectedRewards = DEFAULT_REWARD_RATE * 1 days;
        assertEq(rewards, expectedRewards);
    }

    function test_ViewRewardsWithLargeBalance() public {
        uint256 largeBalance = 1_000_000 * WAD;
        setDepositTokenBalance(largeBalance);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, largeBalance, 0);

        vm.warp(initialTime + 1 days);

        uint256 rewards = staking.viewRewards(alice);

        // When alice has 100% of deposits, she gets all rewards
        // rewards = balance * (rate * time * WAD / totalDeposits) / WAD
        // = largeBalance * (rate * time * WAD / largeBalance) / WAD
        // = rate * time
        uint256 expectedRewards = DEFAULT_REWARD_RATE * 1 days;
        assertApproxEqRel(rewards, expectedRewards, 0.001e18); // 0.1% tolerance for rounding
    }

    function test_ViewRewardsNeverReverts() public {
        // Test that viewRewards never reverts under various conditions

        // Case 1: No deposit
        staking.viewRewards(alice);

        // Case 2: Zero balance
        setUserDeposit(alice, 0, 0);
        staking.viewRewards(alice);

        // Case 3: Normal case
        setDepositTokenBalance(100 * WAD);
        setUserDeposit(alice, 100 * WAD, 0);
        staking.viewRewards(alice);

        // Case 4: High debt
        setUserDeposit(alice, 100 * WAD, 1000 * WAD);
        staking.viewRewards(alice);

        // All should complete without reverting
        assertTrue(true);
    }

    // ===== Comparison: Before and After Update =====

    function test_ViewRewardsBeforeAndAfterUpdate() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        vm.warp(initialTime + 1 days);

        // Check BEFORE update
        uint256 rewardsBefore = staking.viewRewards(alice);

        // Call update
        staking.exposed_updatePool();

        // Check AFTER update (same block)
        uint256 rewardsAfter = staking.viewRewards(alice);

        // Should be the same in the same block
        assertEq(rewardsBefore, rewardsAfter);
    }

    function test_ViewRewardsAccumulatesCorrectlyAcrossUpdates() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        setUserDeposit(alice, 100 * WAD, 0);

        // After 1 day, before update
        vm.warp(initialTime + 1 days);
        uint256 rewards1Before = staking.viewRewards(alice);

        // Update
        staking.exposed_updatePool();
        uint256 rewards1After = staking.viewRewards(alice);

        // After another day, before second update
        vm.warp(initialTime + 2 days);
        uint256 rewards2Before = staking.viewRewards(alice);

        // Second update
        staking.exposed_updatePool();
        uint256 rewards2After = staking.viewRewards(alice);

        // Verify progression
        assertEq(rewards1Before, DEFAULT_REWARD_RATE * 1 days);
        assertEq(rewards1After, DEFAULT_REWARD_RATE * 1 days);
        assertEq(rewards2Before, DEFAULT_REWARD_RATE * 2 days);
        assertEq(rewards2After, DEFAULT_REWARD_RATE * 2 days);
    }

    // ===== Fuzz Tests =====

    function testFuzz_ViewRewardsNeverReverts(
        address user,
        uint128 balance,
        uint128 debt,
        uint32 timeElapsed
    ) public {
        vm.assume(user != address(0));

        if (balance > 0) {
            setDepositTokenBalance(balance);
            setUserDeposit(user, balance, debt);
        }

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        if (timeElapsed > 0) {
            vm.warp(initialTime + timeElapsed);
        }

        // Should never revert
        staking.viewRewards(user);
    }

    function testFuzz_ViewRewardsSameInSameBlock(
        uint128 depositAmount,
        uint32 timeElapsed
    ) public {
        vm.assume(depositAmount > 0);
        vm.assume(timeElapsed > 0);

        setDepositTokenBalance(depositAmount);
        setUserDeposit(alice, depositAmount, 0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + timeElapsed);

        // Multiple calls in same block should return same value
        uint256 rewards1 = staking.viewRewards(alice);
        uint256 rewards2 = staking.viewRewards(alice);
        uint256 rewards3 = staking.viewRewards(alice);

        assertEq(rewards1, rewards2);
        assertEq(rewards2, rewards3);
    }

    function testFuzz_ViewRewardsIncreasesWithTime(
        uint64 depositAmount,
        uint32 time1,
        uint32 time2
    ) public {
        vm.assume(depositAmount > 0);
        vm.assume(time1 > 0);
        vm.assume(time2 > time1);

        uint256 deposits = uint256(depositAmount) * WAD;
        setDepositTokenBalance(deposits);
        setUserDeposit(alice, deposits, 0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Check at time1
        vm.warp(initialTime + time1);
        uint256 rewardsAt1 = staking.viewRewards(alice);

        // Check at time2 (later)
        vm.warp(initialTime + time2);
        uint256 rewardsAt2 = staking.viewRewards(alice);

        // Rewards should increase (or stay same if rate is 0 or rounding to 0)
        assertGe(rewardsAt2, rewardsAt1);

        // If default rate and rewards are non-zero, should strictly increase
        uint256 rate = staking.rewardPerDepositTokenPerSecond();
        if (rate > 0 && rewardsAt1 > 0) {
            // Only assert strict increase if we expect non-zero difference
            // Small time differences might round to 0
            uint256 expectedIncrease = rate * (time2 - time1);
            if (expectedIncrease > 0) {
                assertGt(rewardsAt2, rewardsAt1);
            }
        }
    }
}
