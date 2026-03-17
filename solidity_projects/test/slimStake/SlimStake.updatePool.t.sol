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

// Helper contract to expose internal function
contract SlimStakeHarness is SlimStake {
    constructor(IERC20 _depositToken, IERC20 _rewardToken) SlimStake(_depositToken, _rewardToken) {}

    // Expose internal function for testing
    function exposed_updatePool() external {
        _updatePool();
    }

    // Helper to get current state
    function getAccumulatedRewardsPerDepositTokenWAD() external view returns (uint256) {
        return accumulatedRewardsPerDepositTokenWAD;
    }

    function getLastUpdateTime() external view returns (uint40) {
        return lastUpdateTime;
    }
}

contract SlimStakeUpdatePoolTest is Test {
    SlimStakeHarness public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    uint256 constant WAD = 1e18;
    uint256 constant DEFAULT_REWARD_RATE = 11_574_074_074_074;

    // Storage slot locations (accounting for Ownable and ReentrancyGuard)
    bytes32 constant REWARD_RATE_SLOT = bytes32(uint256(4));
    bytes32 constant ACCUMULATED_REWARDS_SLOT = bytes32(uint256(5));
    bytes32 constant LAST_UPDATE_TIME_SLOT = bytes32(uint256(6));

    function setUp() public {
        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract with harness
        staking = new SlimStakeHarness(depositToken, rewardToken);
    }

    // ===== Helper Functions =====

    function setLastUpdateTime(uint40 timestamp) internal {
        vm.store(
            address(staking),
            LAST_UPDATE_TIME_SLOT,
            bytes32(uint256(timestamp))
        );
    }

    function setRewardRate(uint256 rate) internal {
        vm.store(
            address(staking),
            REWARD_RATE_SLOT,
            bytes32(rate)
        );
    }

    function setAccumulatedRewards(uint256 amount) internal {
        vm.store(
            address(staking),
            ACCUMULATED_REWARDS_SLOT,
            bytes32(amount)
        );
    }

    function setDepositTokenBalance(uint256 amount) internal {
        depositToken.mint(address(staking), amount);
    }

    // ===== Basic Functionality Tests =====

    function test_UpdatePoolSetsLastUpdateTimeToCurrentBlock() public {
        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward
        vm.warp(initialTime + 100);

        staking.exposed_updatePool();

        // lastUpdateTime should be set to current block.timestamp
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));
        assertEq(staking.getLastUpdateTime(), uint40(initialTime + 100));
    }

    function test_UpdatePoolIncreasesAccumulatedRewards() public {
        // Set up: 100 tokens deposited, start from 0 accumulated rewards
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward 1 day
        vm.warp(initialTime + 1 days);

        uint256 accumulatedBefore = staking.getAccumulatedRewardsPerDepositTokenWAD();

        staking.exposed_updatePool();

        uint256 accumulatedAfter = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Should have increased
        assertGt(accumulatedAfter, accumulatedBefore);
    }

    function test_UpdatePoolCalculatesCorrectIncrease() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward 1 day
        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        // Expected increase: rate * timeElapsed * WAD / totalDeposits
        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 actualAccumulated = staking.getAccumulatedRewardsPerDepositTokenWAD();

        assertEq(actualAccumulated, expectedIncrease);
    }

    function test_UpdatePoolAddsToExistingAccumulatedRewards() public {
        setDepositTokenBalance(100 * WAD);

        uint256 initialAccumulated = 50 * WAD;
        setAccumulatedRewards(initialAccumulated);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Warp forward 1 day
        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 expectedTotal = initialAccumulated + expectedIncrease;
        uint256 actualAccumulated = staking.getAccumulatedRewardsPerDepositTokenWAD();

        assertEq(actualAccumulated, expectedTotal);
    }

    // ===== Zero Cases =====

    function test_UpdatePoolWhenNoTimeElapsed() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(50 * WAD);

        uint256 currentTime = block.timestamp;
        setLastUpdateTime(uint40(currentTime));

        // Don't warp - same block
        uint256 accumulatedBefore = staking.getAccumulatedRewardsPerDepositTokenWAD();

        staking.exposed_updatePool();

        uint256 accumulatedAfter = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Accumulated should not change (increase is 0)
        assertEq(accumulatedAfter, accumulatedBefore);

        // But lastUpdateTime should still be set to current timestamp
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));
    }

    function test_UpdatePoolWhenNoDeposits() public {
        // No deposits (totalDeposits = 0)
        setAccumulatedRewards(50 * WAD);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        uint256 accumulatedBefore = staking.getAccumulatedRewardsPerDepositTokenWAD();

        staking.exposed_updatePool();

        uint256 accumulatedAfter = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Accumulated should not change (increase is 0 when no deposits)
        assertEq(accumulatedAfter, accumulatedBefore);

        // lastUpdateTime should still update
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));
    }

    function test_UpdatePoolWhenNoDepositsAndNoTimeElapsed() public {
        setAccumulatedRewards(50 * WAD);

        uint256 currentTime = block.timestamp;
        setLastUpdateTime(uint40(currentTime));

        uint256 accumulatedBefore = staking.getAccumulatedRewardsPerDepositTokenWAD();

        staking.exposed_updatePool();

        uint256 accumulatedAfter = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Should not change
        assertEq(accumulatedAfter, accumulatedBefore);
    }

    function test_UpdatePoolWithZeroRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setRewardRate(0);
        setAccumulatedRewards(50 * WAD);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        uint256 accumulatedBefore = staking.getAccumulatedRewardsPerDepositTokenWAD();

        staking.exposed_updatePool();

        uint256 accumulatedAfter = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Should not change when rate is 0
        assertEq(accumulatedAfter, accumulatedBefore);
    }

    // ===== Multiple Updates =====

    function test_UpdatePoolMultipleTimes() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // First update after 1 hour
        vm.warp(initialTime + 1 hours);
        staking.exposed_updatePool();

        uint256 accumulatedAfter1 = staking.getAccumulatedRewardsPerDepositTokenWAD();
        uint256 expectedAfter1 = (DEFAULT_REWARD_RATE * 1 hours * WAD) / (100 * WAD);
        assertEq(accumulatedAfter1, expectedAfter1);

        // Second update after another hour (2 hours total from start)
        vm.warp(initialTime + 2 hours);
        staking.exposed_updatePool();

        uint256 accumulatedAfter2 = staking.getAccumulatedRewardsPerDepositTokenWAD();
        // Total should be 2 hours worth
        uint256 expectedAfter2 = (DEFAULT_REWARD_RATE * 2 hours * WAD) / (100 * WAD);
        assertEq(accumulatedAfter2, expectedAfter2);

        // Third update after another hour (3 hours total from start)
        vm.warp(initialTime + 3 hours);
        staking.exposed_updatePool();

        uint256 accumulatedAfter3 = staking.getAccumulatedRewardsPerDepositTokenWAD();
        uint256 expectedAfter3 = (DEFAULT_REWARD_RATE * 3 hours * WAD) / (100 * WAD);
        assertEq(accumulatedAfter3, expectedAfter3);
    }

    function test_UpdatePoolConsecutiveCallsSameBlock() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 hours);

        // First call
        staking.exposed_updatePool();
        uint256 accumulatedAfter1 = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Second call in same block
        staking.exposed_updatePool();
        uint256 accumulatedAfter2 = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Should be the same (no time elapsed)
        assertEq(accumulatedAfter1, accumulatedAfter2);
    }

    function test_UpdatePoolMultipleTimesWithChangingDeposits() public {
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        // Start with 100 tokens
        setDepositTokenBalance(100 * WAD);

        vm.warp(initialTime + 1 hours);
        staking.exposed_updatePool();
        uint256 accumulated1 = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // Change to 200 tokens
        depositToken.mint(address(staking), 100 * WAD); // Now 200 total

        vm.warp(initialTime + 2 hours);
        staking.exposed_updatePool();
        uint256 accumulated2 = staking.getAccumulatedRewardsPerDepositTokenWAD();

        // First hour: rate * 3600 * WAD / 100e18
        // Second hour: rate * 3600 * WAD / 200e18
        uint256 expected1 = (DEFAULT_REWARD_RATE * 1 hours * WAD) / (100 * WAD);
        uint256 expected2 = expected1 + (DEFAULT_REWARD_RATE * 1 hours * WAD) / (200 * WAD);

        assertEq(accumulated1, expected1);
        assertEq(accumulated2, expected2);
    }

    // ===== Different Time Periods =====

    function test_UpdatePoolAfterOneSecond() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1);

        staking.exposed_updatePool();

        uint256 expected = (DEFAULT_REWARD_RATE * 1 * WAD) / (100 * WAD);
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    function test_UpdatePoolAfterOneYear() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 365 days);

        staking.exposed_updatePool();

        uint256 expected = (DEFAULT_REWARD_RATE * 365 days * WAD) / (100 * WAD);
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    // ===== Different Reward Rates =====

    function test_UpdatePoolWithHighRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);

        uint256 highRate = DEFAULT_REWARD_RATE * 100;
        setRewardRate(highRate);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expected = (highRate * 1 days * WAD) / (100 * WAD);
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    function test_UpdatePoolWithVerySmallRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setAccumulatedRewards(0);
        setRewardRate(1);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expected = (1 * 1 days * WAD) / (100 * WAD);
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    // ===== Different Deposit Amounts =====

    function test_UpdatePoolWithSmallDeposit() public {
        setDepositTokenBalance(1); // 1 wei
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expected = (DEFAULT_REWARD_RATE * 1 days * WAD) / 1;
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    function test_UpdatePoolWithLargeDeposit() public {
        setDepositTokenBalance(1_000_000 * WAD);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expected = (DEFAULT_REWARD_RATE * 1 days * WAD) / (1_000_000 * WAD);
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expected);
    }

    // ===== Edge Cases =====

    function test_UpdatePoolWithLargeAccumulatedRewards() public {
        setDepositTokenBalance(100 * WAD);

        // Start with very large accumulated rewards
        uint256 largeAccumulated = 1_000_000_000 * WAD;
        setAccumulatedRewards(largeAccumulated);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1 days);

        staking.exposed_updatePool();

        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);
        uint256 expectedTotal = largeAccumulated + expectedIncrease;

        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expectedTotal);
    }

    function test_UpdatePoolNeverReverts() public {
        // Should never revert under any circumstances

        // Case 1: Normal update
        setDepositTokenBalance(100 * WAD);
        vm.warp(block.timestamp + 2000);
        setLastUpdateTime(uint40(block.timestamp - 1000));
        staking.exposed_updatePool();

        // Case 2: No deposits
        vm.store(address(depositToken), keccak256(abi.encode(address(staking), 0)), bytes32(0));
        staking.exposed_updatePool();

        // Case 3: No time elapsed
        setLastUpdateTime(uint40(block.timestamp));
        staking.exposed_updatePool();

        // Case 4: Zero rate
        setRewardRate(0);
        staking.exposed_updatePool();
    }

    // ===== Timestamp Update Tests =====

    function test_UpdatePoolAlwaysUpdatesTimestamp() public {
        uint256 initialTime = block.timestamp + 2000;
        vm.warp(initialTime);
        setLastUpdateTime(uint40(initialTime - 1000));

        // Update at current time
        staking.exposed_updatePool();
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));

        // Warp and update again
        vm.warp(initialTime + 5000);
        staking.exposed_updatePool();
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));

        // Update again in same block
        staking.exposed_updatePool();
        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));
    }

    function test_UpdatePoolTimestampFitsInUint40() public {
        // Test that casting to uint40 works correctly
        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + 1000);

        staking.exposed_updatePool();

        uint40 lastUpdate = staking.getLastUpdateTime();
        assertEq(uint256(lastUpdate), block.timestamp);
        assertLe(uint256(lastUpdate), type(uint40).max);
    }

    // ===== Fuzz Tests =====

    function testFuzz_UpdatePoolNeverReverts(
        uint128 depositAmount,
        uint128 rewardRate,
        uint32 initialTime,
        uint32 timeElapsed
    ) public {
        vm.assume(initialTime > 0);
        vm.assume(initialTime < type(uint40).max - timeElapsed);

        if (depositAmount > 0) {
            setDepositTokenBalance(depositAmount);
        }

        if (rewardRate > 0) {
            setRewardRate(rewardRate);
        }

        vm.warp(initialTime);
        setLastUpdateTime(uint40(initialTime));

        if (timeElapsed > 0) {
            vm.warp(uint256(initialTime) + uint256(timeElapsed));
        }

        // Should never revert
        staking.exposed_updatePool();
    }

    function testFuzz_UpdatePoolAlwaysUpdatesTimestamp(uint32 timeElapsed) public {
        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.assume(timeElapsed > 0);
        vm.warp(initialTime + timeElapsed);

        staking.exposed_updatePool();

        assertEq(staking.getLastUpdateTime(), uint40(block.timestamp));
    }

    function testFuzz_UpdatePoolCorrectCalculation(
        uint64 depositAmount,
        uint64 rewardRate,
        uint32 timeElapsed
    ) public {
        vm.assume(depositAmount > 0);
        vm.assume(timeElapsed > 0);

        uint256 deposits = uint256(depositAmount) * WAD;
        setDepositTokenBalance(deposits);
        setRewardRate(rewardRate);
        setAccumulatedRewards(0);

        uint256 initialTime = block.timestamp;
        setLastUpdateTime(uint40(initialTime));

        vm.warp(initialTime + timeElapsed);

        staking.exposed_updatePool();

        uint256 expectedIncrease = (uint256(rewardRate) * uint256(timeElapsed) * WAD) / deposits;
        assertEq(staking.getAccumulatedRewardsPerDepositTokenWAD(), expectedIncrease);
    }
}
