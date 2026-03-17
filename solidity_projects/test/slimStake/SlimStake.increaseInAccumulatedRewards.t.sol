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
    function exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate() external view returns (uint256) {
        return _increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
    }

        function setTotalDeposits(uint256 amount) external {
         totalDeposits = amount;
       }

    // Helper to get current lastUpdateTime for verification
    function getLastUpdateTime() external view returns (uint40) {
        return lastUpdateTime;
    }

    // Helper to get current rewardPerDepositTokenPerSecond for verification
    function getRewardRate() external view returns (uint256) {
        return rewardPerDepositTokenPerSecond;
    }
}

contract SlimStakeIncreaseInAccumulatedRewardsTest is Test {
    SlimStakeHarness public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    uint256 constant WAD = 1e18;
    uint256 constant DEFAULT_REWARD_RATE = 11_574_074_074_074;

    // Storage slot locations (accounting for Ownable and ReentrancyGuard)
    // Ownable: slot 0 (_owner)
    // ReentrancyGuard: slot 1 (_status)
    // SlimStake starts at slot 2
    bytes32 constant REWARD_RATE_SLOT = bytes32(uint256(4)); // rewardPerDepositTokenPerSecond
    bytes32 constant LAST_UPDATE_TIME_SLOT = bytes32(uint256(6)); // lastUpdateTime

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

    function setDepositTokenBalance(uint256 amount) internal {
        depositToken.mint(address(staking), amount);
        staking.setTotalDeposits(amount); 
    }

    // ===== Zero Cases =====

    function test_IncreaseReturnsZeroWhenNoDeposits() public view {
        // No deposits, so totalDeposits = 0
        // Should return 0 regardless of time elapsed
        uint256 increase = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
        assertEq(increase, 0);
    }

    function test_IncreaseReturnsZeroWhenNoTimeElapsed() public {
        // Set some deposits
        setDepositTokenBalance(100 * WAD);

        // Time hasn't changed since deployment, so timeElapsed = 0
        uint256 increase = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
        assertEq(increase, 0);
    }

    function test_IncreaseReturnsZeroWhenBothAreZero() public view {
        // No deposits and no time elapsed
        uint256 increase = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
        assertEq(increase, 0);
    }

    // ===== Normal Cases =====

    function test_IncreaseNormalCase() public {
        // Set up: 100 tokens deposited, 1 day elapsed
        setDepositTokenBalance(100 * WAD);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        // Warp forward 1 day
        vm.warp(deployTime + 1 days);

        // Expected: rate * timeElapsed * WAD / totalDeposits
        // = 11_574_074_074_074 * 86400 * 1e18 / 100e18
        // = rate * 86400 * 1e18 / 100e18
        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 86400 * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function test_IncreaseWithSmallTimeElapsed() public {
        setDepositTokenBalance(100 * WAD);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        // Warp forward 1 second
        vm.warp(deployTime + 1);

        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 1 * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function test_IncreaseWithLargeTimeElapsed() public {
        setDepositTokenBalance(100 * WAD);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        // Warp forward 1 year
        vm.warp(deployTime + 365 days);

        uint256 timeElapsed = 365 days;
        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * timeElapsed * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    // ===== Different Deposit Amounts =====

    function test_IncreaseWithSmallDeposit() public {
        // 1 wei deposited
        setDepositTokenBalance(1);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1 days);

        // With very small deposit, increase should be very large
        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 86400 * WAD) / 1;
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function test_IncreaseWithLargeDeposit() public {
        // 1 million tokens deposited
        setDepositTokenBalance(1_000_000 * WAD);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1 days);

        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 86400 * WAD) / (1_000_000 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    // ===== Different Reward Rates =====

    function test_IncreaseWithZeroRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setRewardRate(0);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1 days);

        // With 0 reward rate, increase should be 0
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
        assertEq(actualIncrease, 0);
    }

    function test_IncreaseWithHighRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        uint256 highRate = DEFAULT_REWARD_RATE * 1000; // 1000x default rate
        setRewardRate(highRate);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1 days);

        uint256 expectedIncrease = (highRate * 86400 * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function test_IncreaseWithVerySmallRewardRate() public {
        setDepositTokenBalance(100 * WAD);
        setRewardRate(1); // 1 wei per second per deposited token

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1 days);

        uint256 expectedIncrease = (1 * 86400 * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    // ===== Precision Tests =====

    function test_IncreasePrecisionWithSmallValues() public {
        // Small deposit, small time
        setDepositTokenBalance(1 * WAD);

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1);

        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * 1 * WAD) / (1 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
        assertEq(actualIncrease, DEFAULT_REWARD_RATE);
    }

    function test_IncreaseRoundingDown() public {
        // Set up values that will cause rounding
        setDepositTokenBalance(3 * WAD);
        setRewardRate(1); // Very small rate

        uint256 deployTime = block.timestamp;
        setLastUpdateTime(uint40(deployTime));

        vm.warp(deployTime + 1);

        // Expected: 1 * 1 * 1e18 / 3e18 = 0 (rounds down)
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
        assertEq(actualIncrease, 0);
    }

    // ===== Multiple Time Periods =====

    function test_IncreaseMultipleCallsWithTimeWarps() public {
        setDepositTokenBalance(100 * WAD);

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        // First check after 1 hour
        vm.warp(startTime + 1 hours);
        uint256 increase1 = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        // Second check after 1 day (total)
        vm.warp(startTime + 1 days);
        uint256 increase2 = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        // increase2 should be larger than increase1 (same lastUpdateTime, more time elapsed)
        assertGt(increase2, increase1);

        // Verify calculation
        uint256 expected1 = (DEFAULT_REWARD_RATE * 1 hours * WAD) / (100 * WAD);
        uint256 expected2 = (DEFAULT_REWARD_RATE * 1 days * WAD) / (100 * WAD);

        assertEq(increase1, expected1);
        assertEq(increase2, expected2);
    }

    function test_IncreaseAfterUpdatingLastTime() public {
        setDepositTokenBalance(100 * WAD);

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        // Warp forward
        vm.warp(startTime + 1 days);
        uint256 increase1 = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        // Update lastUpdateTime to current time
        setLastUpdateTime(uint40(block.timestamp));

        // Call again immediately - should return 0 since no time elapsed
        uint256 increase2 = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertGt(increase1, 0);
        assertEq(increase2, 0);
    }

    // ===== Edge Cases =====

    function test_IncreaseWithMaxUint40Time() public {
        setDepositTokenBalance(100 * WAD);

        // Set lastUpdateTime to a very old time
        setLastUpdateTime(1);

        // Set current time to near max uint40 (but safe)
        uint40 futureTime = type(uint40).max / 2;
        vm.warp(futureTime);

        // Should not revert, even with very large time difference
        uint256 timeElapsed = uint256(futureTime) - 1;
        uint256 expectedIncrease = (DEFAULT_REWARD_RATE * timeElapsed * WAD) / (100 * WAD);
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function test_IncreaseImmediatelyAfterDeployment() public {
        // Create new contract to test initial state
        SlimStakeHarness newStaking = new SlimStakeHarness(depositToken, rewardToken);

        // Add deposits
        depositToken.mint(address(newStaking), 100 * WAD);

        // Call immediately (same block)
        uint256 increase = newStaking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        // Should be 0 since no time has elapsed
        assertEq(increase, 0);
    }

    // ===== Formula Verification =====

    function test_IncreaseFormulaVerification() public {
        uint256 deposits = 50 * WAD;
        uint256 rate = 1000;
        uint256 timeElapsed = 3600; // 1 hour

        setDepositTokenBalance(deposits);
        setRewardRate(rate);

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        vm.warp(startTime + timeElapsed);

        // Manual calculation: rate * timeElapsed * WAD / deposits
        uint256 expectedIncrease = (rate * timeElapsed * WAD) / deposits;
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    // ===== Fuzz Tests =====

    function testFuzz_IncreaseNeverReverts(
        uint128 depositAmount,
        uint128 rewardRate,
        uint32 timeElapsed
    ) public {
        // Set up state
        if (depositAmount > 0) {
            setDepositTokenBalance(depositAmount);
        }

        if (rewardRate > 0) {
            setRewardRate(rewardRate);
        }

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        if (timeElapsed > 0) {
            vm.warp(startTime + timeElapsed);
        }

        // Should never revert
        staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
    }

    function testFuzz_IncreaseCorrectCalculation(
        uint64 depositAmount,
        uint64 rewardRate,
        uint32 timeElapsed
    ) public {
        vm.assume(depositAmount > 0);
        vm.assume(timeElapsed > 0);

        uint256 deposits = uint256(depositAmount) * WAD;

        setDepositTokenBalance(deposits);
        setRewardRate(rewardRate);

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        vm.warp(startTime + timeElapsed);

        uint256 expectedIncrease = (uint256(rewardRate) * uint256(timeElapsed) * WAD) / deposits;
        uint256 actualIncrease = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        assertEq(actualIncrease, expectedIncrease);
    }

    function testFuzz_IncreaseReturnsZeroWhenAppropriate(
        uint128 depositAmount,
        uint32 timeElapsed
    ) public {
        bool hasDeposits = depositAmount > 0;
        bool hasTimeElapsed = timeElapsed > 0;

        if (hasDeposits) {
            setDepositTokenBalance(depositAmount);
        }

        uint256 startTime = block.timestamp;
        setLastUpdateTime(uint40(startTime));

        if (hasTimeElapsed) {
            vm.warp(startTime + timeElapsed);
        }

        uint256 increase = staking.exposed_increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

        // Should return 0 if either deposits or time is 0
        if (!hasDeposits || !hasTimeElapsed) {
            assertEq(increase, 0);
        }
    }
}
