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

contract SlimStakeSetRewardRateTest is Test {
    SlimStake public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant WAD = 1e18;
    uint256 constant DEFAULT_REWARD_RATE = 11_574_074_074_074;

    // Storage slot locations
    bytes32 constant REWARD_RATE_SLOT = bytes32(uint256(4));
    bytes32 constant ACCUMULATED_REWARDS_SLOT = bytes32(uint256(5));
    bytes32 constant LAST_UPDATE_TIME_SLOT = bytes32(uint256(6));

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract
        staking = new SlimStake(depositToken, rewardToken);
    }

    // ===== Helper Functions =====

    function setLastUpdateTime(uint40 timestamp) internal {
        vm.store(address(staking), LAST_UPDATE_TIME_SLOT, bytes32(uint256(timestamp)));
    }

    function setAccumulatedRewards(uint256 amount) internal {
        vm.store(address(staking), ACCUMULATED_REWARDS_SLOT, bytes32(amount));
    }

    function setDepositTokenBalance(uint256 amount) internal {
        depositToken.mint(address(staking), amount);
    }

    // ===== Access Control Tests =====

    function test_SetRewardRateOnlyOwnerCanCall() public {
        uint256 newRate = 20_000_000_000_000;

        // Owner can call
        staking.setRewardRate(newRate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), newRate);
    }

    function test_SetRewardRateNonOwnerCannotCall() public {
        uint256 newRate = 20_000_000_000_000;

        // Non-owner cannot call
        vm.prank(alice);
        vm.expectRevert();
        staking.setRewardRate(newRate);
    }

    function test_SetRewardRateRevertsForNonOwner() public {
        vm.prank(bob);
        vm.expectRevert();
        staking.setRewardRate(1000);
    }

    // ===== Rate Change Tests =====

    function test_SetRewardRateChangesRate() public {
        uint256 newRate = 20_000_000_000_000;

        uint256 oldRate = staking.rewardPerDepositTokenPerSecond();
        assertEq(oldRate, DEFAULT_REWARD_RATE);

        staking.setRewardRate(newRate);

        uint256 currentRate = staking.rewardPerDepositTokenPerSecond();
        assertEq(currentRate, newRate);
        assertNotEq(currentRate, oldRate);
    }

    function test_SetRewardRateToZero() public {
        staking.setRewardRate(0);
        assertEq(staking.rewardPerDepositTokenPerSecond(), 0);
    }

    function test_SetRewardRateToVeryLarge() public {
        uint256 largeRate = type(uint128).max;
        staking.setRewardRate(largeRate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), largeRate);
    }

    function test_SetRewardRateToSameValue() public {
        uint256 currentRate = staking.rewardPerDepositTokenPerSecond();

        staking.setRewardRate(currentRate);

        assertEq(staking.rewardPerDepositTokenPerSecond(), currentRate);
    }

    function test_SetRewardRateMultipleTimes() public {
        uint256 rate1 = 1000;
        uint256 rate2 = 2000;
        uint256 rate3 = 3000;

        staking.setRewardRate(rate1);
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate1);

        staking.setRewardRate(rate2);
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate2);

        staking.setRewardRate(rate3);
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate3);
    }

    // ===== Event Emission Tests =====

    function test_SetRewardRateEmitsEvent() public {
        uint256 newRate = 20_000_000_000_000;

        vm.expectEmit(false, false, false, true);
        emit SlimStake.SetRewardRate(block.timestamp, newRate);

        staking.setRewardRate(newRate);
    }

    function test_SetRewardRateEventIncludesTimestamp() public {
        uint256 newRate = 1000;
        uint256 expectedTimestamp = block.timestamp;

        vm.expectEmit(false, false, false, true);
        emit SlimStake.SetRewardRate(expectedTimestamp, newRate);

        staking.setRewardRate(newRate);
    }

    function test_SetRewardRateEmitsEventWithCorrectRate() public {
        uint256 newRate = 999_999_999_999;

        vm.expectEmit(false, false, false, true);
        emit SlimStake.SetRewardRate(block.timestamp, newRate);

        staking.setRewardRate(newRate);
    }

    // ===== Pool Update Tests =====

    function test_SetRewardRateUpdatesPoolFirst() public {
        // Setup: deposits exist, time has passed
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward
        vm.warp(initialTime + 1 days);

        uint256 accumulatedBefore = staking.accumulatedRewardsPerDepositTokenWAD();

        // Set new rate
        staking.setRewardRate(1000);

        uint256 accumulatedAfter = staking.accumulatedRewardsPerDepositTokenWAD();

        // Accumulated should have increased (pool was updated)
        assertGt(accumulatedAfter, accumulatedBefore);
    }

    function test_SetRewardRateUpdatesLastUpdateTime() public {
        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 hours);

        // Set new rate
        staking.setRewardRate(1000);

        // lastUpdateTime should be current timestamp
        assertEq(staking.lastUpdateTime(), uint40(block.timestamp));
    }

    function test_SetRewardRatePreservesOldRateRewards() public {
        // Setup: user has deposits, time passes, then rate changes
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward 1 day
        vm.warp(initialTime + 1 days);

        // Change rate
        staking.setRewardRate(1000);

        // Accumulated should reflect 1 day at old rate
        uint256 expectedAccumulated = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 actualAccumulated = staking.accumulatedRewardsPerDepositTokenWAD();

        assertEq(actualAccumulated, expectedAccumulated);
    }

    // ===== Integration with Rewards Tests =====

    function test_SetRewardRateAffectsFutureRewards() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Wait 1 day with default rate
        vm.warp(initialTime + 1 days);

        // Change to 2x rate
        staking.setRewardRate(DEFAULT_REWARD_RATE * 2);

        // Wait another day
        vm.warp(initialTime + 2 days);

        // Calculate expected total accumulated
        // Day 1: default rate
        // Day 2: 2x rate
        uint256 day1Accumulated = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 day2Accumulated = (DEFAULT_REWARD_RATE * 2 * 1 days * WAD) / (100 * WAD);
        uint256 expectedTotal = day1Accumulated + day2Accumulated;

        // Trigger update by setting rate again
        staking.setRewardRate(DEFAULT_REWARD_RATE * 2);

        uint256 actualTotal = staking.accumulatedRewardsPerDepositTokenWAD();

        assertEq(actualTotal, expectedTotal);
    }

    function test_SetRewardRateDoesNotAffectPastRewards() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(50 * WAD); // Start with some accumulated

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Don't warp - change rate immediately
        staking.setRewardRate(1000);

        // Accumulated should stay the same (no time elapsed)
        assertEq(staking.accumulatedRewardsPerDepositTokenWAD(), 50 * WAD);
    }

    // ===== Rate Increase vs Decrease Tests =====

    function test_SetRewardRateIncrease() public {
        uint256 oldRate = staking.rewardPerDepositTokenPerSecond();
        uint256 newRate = oldRate * 10;

        staking.setRewardRate(newRate);

        assertGt(staking.rewardPerDepositTokenPerSecond(), oldRate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), newRate);
    }

    function test_SetRewardRateDecrease() public {
        uint256 oldRate = staking.rewardPerDepositTokenPerSecond();
        uint256 newRate = oldRate / 10;

        staking.setRewardRate(newRate);

        assertLt(staking.rewardPerDepositTokenPerSecond(), oldRate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), newRate);
    }

    function test_SetRewardRateToggleBetweenZeroAndNonZero() public {
        // Start with default rate
        assertEq(staking.rewardPerDepositTokenPerSecond(), DEFAULT_REWARD_RATE);

        // Set to zero
        staking.setRewardRate(0);
        assertEq(staking.rewardPerDepositTokenPerSecond(), 0);

        // Set back to non-zero
        staking.setRewardRate(1000);
        assertEq(staking.rewardPerDepositTokenPerSecond(), 1000);

        // Set to zero again
        staking.setRewardRate(0);
        assertEq(staking.rewardPerDepositTokenPerSecond(), 0);
    }

    // ===== Edge Cases =====

    function test_SetRewardRateWhenNoDeposits() public {
        // No deposits in contract
        uint256 newRate = 5000;

        staking.setRewardRate(newRate);

        assertEq(staking.rewardPerDepositTokenPerSecond(), newRate);
    }

    function test_SetRewardRateMultipleTimesInSameBlock() public {
        uint256 rate1 = 1000;
        uint256 rate2 = 2000;
        uint256 rate3 = 3000;

        staking.setRewardRate(rate1);
        staking.setRewardRate(rate2);
        staking.setRewardRate(rate3);

        // Should end up with rate3
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate3);
    }

    function test_SetRewardRateImmediatelyAfterDeployment() public {
        SlimStake newStaking = new SlimStake(depositToken, rewardToken);

        uint256 newRate = 999;
        newStaking.setRewardRate(newRate);

        assertEq(newStaking.rewardPerDepositTokenPerSecond(), newRate);
    }

    // ===== Complex Scenarios =====

    function test_SetRewardRateMultipleChangesOverTime() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        // Period 1: Default rate for 1 hour
        vm.warp(startTime + 1 hours);
        staking.setRewardRate(DEFAULT_REWARD_RATE * 2); // 2x rate

        // Period 2: 2x rate for 1 hour
        vm.warp(startTime + 2 hours);
        staking.setRewardRate(DEFAULT_REWARD_RATE * 3); // 3x rate

        // Period 3: 3x rate for 1 hour
        vm.warp(startTime + 3 hours);
        staking.setRewardRate(DEFAULT_REWARD_RATE); // Back to default

        // Calculate expected accumulated
        uint256 period1 = (DEFAULT_REWARD_RATE * 1 hours * WAD) / (100 * WAD);
        uint256 period2 = (DEFAULT_REWARD_RATE * 2 * 1 hours * WAD) / (100 * WAD);
        uint256 period3 = (DEFAULT_REWARD_RATE * 3 * 1 hours * WAD) / (100 * WAD);
        uint256 expectedTotal = period1 + period2 + period3;

        assertEq(staking.accumulatedRewardsPerDepositTokenWAD(), expectedTotal);
    }

    function test_SetRewardRateAfterLongPeriod() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Wait 1 year
        vm.warp(initialTime + 365 days);

        uint256 accumulatedBefore = staking.accumulatedRewardsPerDepositTokenWAD();

        // Change rate
        staking.setRewardRate(1000);

        uint256 accumulatedAfter = staking.accumulatedRewardsPerDepositTokenWAD();

        // Should have accumulated rewards for the year at old rate
        uint256 expectedAccumulated = (DEFAULT_REWARD_RATE * 365 days * WAD) / (100 * WAD);

        assertEq(accumulatedBefore, 0); // Before calling setRewardRate
        assertEq(accumulatedAfter, expectedAccumulated); // After calling setRewardRate
    }

    // ===== State Verification Tests =====

    function test_SetRewardRateDoesNotChangeOtherState() public {
        // Set some initial state
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(50 * WAD);

        uint256 depositsBefore = depositToken.balanceOf(address(staking));
        uint256 rewardsBefore = rewardToken.balanceOf(address(staking));

        // Change rate
        staking.setRewardRate(1000);

        uint256 depositsAfter = depositToken.balanceOf(address(staking));
        uint256 rewardsAfter = rewardToken.balanceOf(address(staking));

        // Token balances should not change
        assertEq(depositsAfter, depositsBefore);
        assertEq(rewardsAfter, rewardsBefore);
    }

    function test_SetRewardRateNeverReverts() public {
        // Should never revert when called by owner

        // Case 1: Normal rate change
        staking.setRewardRate(1000);

        // Case 2: Zero rate
        staking.setRewardRate(0);

        // Case 3: Very large rate
        staking.setRewardRate(type(uint256).max);

        // Case 4: Back to normal
        staking.setRewardRate(DEFAULT_REWARD_RATE);

        // All should succeed
        assertTrue(true);
    }

    // ===== Ownership Transfer Tests =====

    function test_SetRewardRateAfterOwnershipTransfer() public {
        // Transfer ownership to Alice
        staking.transferOwnership(alice);

        // Alice can now set rate
        vm.prank(alice);
        staking.setRewardRate(5000);
        assertEq(staking.rewardPerDepositTokenPerSecond(), 5000);

        // Original owner cannot
        vm.expectRevert();
        staking.setRewardRate(6000);
    }

    // ===== Fuzz Tests =====

    function testFuzz_SetRewardRateOnlyOwnerCanCall(address caller, uint256 rate) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert();
        staking.setRewardRate(rate);

        // Owner can always call
        staking.setRewardRate(rate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate);
    }

    function testFuzz_SetRewardRateChangesRate(uint256 newRate) public {
        staking.setRewardRate(newRate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), newRate);
    }

    function testFuzz_SetRewardRateEmitsEvent(uint256 newRate) public {
        vm.expectEmit(false, false, false, true);
        emit SlimStake.SetRewardRate(block.timestamp, newRate);

        staking.setRewardRate(newRate);
    }

    function testFuzz_SetRewardRateNeverReverts(uint256 rate) public {
        // Should never revert when called by owner
        staking.setRewardRate(rate);
        assertEq(staking.rewardPerDepositTokenPerSecond(), rate);
    }

    function testFuzz_SetRewardRateUpdatesTimestamp(uint256 rate, uint32 initialTime) public {
        vm.assume(initialTime > 0 && initialTime < type(uint40).max);

        vm.warp(initialTime);
        setLastUpdateTime(uint40(initialTime));

        staking.setRewardRate(rate);

        assertEq(staking.lastUpdateTime(), uint40(block.timestamp));
    }
}
