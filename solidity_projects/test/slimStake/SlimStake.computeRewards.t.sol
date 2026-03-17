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

// Helper contract to expose internal _computeRewards function
contract SlimStakeHarness is SlimStake {
    constructor(IERC20 _depositToken, IERC20 _rewardToken) SlimStake(_depositToken, _rewardToken) {}

    // Expose internal function for testing
    function exposed_computeRewards(
        uint256 balance,
        uint256 debt,
        uint256 _accumulatedRewardsPerDepositTokenWAD
    ) external pure returns (uint256) {
        return _computeRewards(balance, debt, _accumulatedRewardsPerDepositTokenWAD);
    }
}

contract SlimStakeComputeRewardsTest is Test {
    SlimStakeHarness public staking;
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    uint256 constant WAD = 1e18;

    function setUp() public {
        // Deploy tokens
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");

        // Deploy staking contract with harness
        staking = new SlimStakeHarness(depositToken, rewardToken);
    }

    // ===== Normal Cases =====

    function test_ComputeRewardsNormalCase() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 50 * WAD;
        uint256 accumulatedRewards = 2 * WAD; // 2 WAD per token

        // Expected: balance * accumulatedRewards / WAD - debt
        // = 100e18 * 2e18 / 1e18 - 50e18 = 200e18 - 50e18 = 150e18
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 150 * WAD);
    }

    function test_ComputeRewardsWhenAccRewardsEqualsDebt() public view {
        uint256 balance = 100 * WAD;
        uint256 accumulatedRewards = 1 * WAD;
        uint256 debt = balance * accumulatedRewards / WAD; // Equals accRewards

        // When accRewards == debt, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function test_ComputeRewardsWhenDebtExceedsAccRewards() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 200 * WAD;
        uint256 accumulatedRewards = 1 * WAD;

        // accRewards = 100e18 * 1e18 / 1e18 = 100e18
        // debt = 200e18
        // Since accRewards < debt, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    // ===== Zero Value Edge Cases =====

    function test_ComputeRewardsZeroBalance() public view {
        uint256 balance = 0;
        uint256 debt = 50 * WAD;
        uint256 accumulatedRewards = 2 * WAD;

        // With balance = 0, accRewards = 0 * 2e18 / 1e18 = 0
        // Since 0 < debt, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function test_ComputeRewardsZeroDebt() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 0;
        uint256 accumulatedRewards = 2 * WAD;

        // accRewards = 100e18 * 2e18 / 1e18 = 200e18
        // rewards = 200e18 - 0 = 200e18
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 200 * WAD);
    }

    function test_ComputeRewardsZeroAccumulatedRewards() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 50 * WAD;
        uint256 accumulatedRewards = 0;

        // accRewards = 100e18 * 0 / 1e18 = 0
        // Since 0 < debt, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function test_ComputeRewardsAllZeros() public view {
        uint256 balance = 0;
        uint256 debt = 0;
        uint256 accumulatedRewards = 0;

        // Everything is 0, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function test_ComputeRewardsZeroBalanceZeroDebt() public view {
        uint256 balance = 0;
        uint256 debt = 0;
        uint256 accumulatedRewards = 5 * WAD;

        // accRewards = 0, debt = 0, should return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    // ===== Small Values =====

    function test_ComputeRewardsSmallBalance() public view {
        uint256 balance = 1; // 1 wei
        uint256 debt = 0;
        uint256 accumulatedRewards = 1 * WAD;

        // accRewards = 1 * 1e18 / 1e18 = 1
        // rewards = 1 - 0 = 1
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 1);
    }

    function test_ComputeRewardsSmallAccumulatedRewards() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 0;
        uint256 accumulatedRewards = 1; // 1 wei (not scaled by WAD)

        // accRewards = 100e18 * 1 / 1e18 = 100
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 100);
    }

    function test_ComputeRewardsRoundingDown() public view {
        uint256 balance = 1;
        uint256 debt = 0;
        uint256 accumulatedRewards = WAD - 1; // Slightly less than 1 WAD

        // accRewards = 1 * (1e18 - 1) / 1e18 = 0 (rounds down)
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    // ===== Large Values =====

    function test_ComputeRewardsLargeValues() public view {
        uint256 balance = 1_000_000 * WAD; // 1 million tokens
        uint256 debt = 500_000 * WAD; // 500k tokens
        uint256 accumulatedRewards = 10 * WAD; // 10 WAD per token

        // accRewards = 1_000_000e18 * 10e18 / 1e18 = 10_000_000e18
        // rewards = 10_000_000e18 - 500_000e18 = 9_500_000e18
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 9_500_000 * WAD);
    }

    function test_ComputeRewardsVeryLargeAccumulatedRewards() public view {
        uint256 balance = 100 * WAD;
        uint256 debt = 0;
        uint256 accumulatedRewards = 1_000_000 * WAD; // Very high accumulated rewards

        // accRewards = 100e18 * 1_000_000e18 / 1e18 = 100_000_000e18
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 100_000_000 * WAD);
    }

    // ===== Precision Tests =====

    function test_ComputeRewardsPrecision() public view {
        uint256 balance = 333_333_333_333_333_333; // ~0.333 tokens
        uint256 debt = 0;
        uint256 accumulatedRewards = 3 * WAD;

        // accRewards = 333_333_333_333_333_333 * 3e18 / 1e18
        // = 999_999_999_999_999_999 (~1 token minus 1 wei)
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 999_999_999_999_999_999);
    }

    function test_ComputeRewardsDebtOffByOne() public view {
        uint256 balance = 100 * WAD;
        uint256 accumulatedRewards = 2 * WAD;
        uint256 debt = (balance * accumulatedRewards / WAD) - 1; // 1 wei less than accRewards

        // accRewards = 200e18
        // debt = 200e18 - 1
        // rewards = 1
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 1);
    }

    function test_ComputeRewardsDebtOffByOneTooMuch() public view {
        uint256 balance = 100 * WAD;
        uint256 accumulatedRewards = 2 * WAD;
        uint256 debt = (balance * accumulatedRewards / WAD) + 1; // 1 wei more than accRewards

        // accRewards = 200e18
        // debt = 200e18 + 1
        // Since accRewards < debt, return 0
        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    // ===== Real-world Scenarios =====

    function test_ComputeRewardsImmediatelyAfterDeposit() public view {
        // After a fresh deposit, debt should equal accRewards, so rewards = 0
        uint256 balance = 100 * WAD;
        uint256 accumulatedRewards = 5 * WAD;
        uint256 debt = balance * accumulatedRewards / WAD; // Set debt as it would be after deposit

        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function test_ComputeRewardsAfterSomeTimeElapsed() public view {
        // Simulating rewards after some time
        uint256 balance = 100 * WAD;
        uint256 initialAccRewards = 5 * WAD;
        uint256 debt = balance * initialAccRewards / WAD; // Debt set at deposit
        uint256 currentAccRewards = 7 * WAD; // Accumulated rewards increased

        // accRewards = 100e18 * 7e18 / 1e18 = 700e18
        // debt = 100e18 * 5e18 / 1e18 = 500e18
        // rewards = 700e18 - 500e18 = 200e18
        uint256 rewards = staking.exposed_computeRewards(balance, debt, currentAccRewards);

        assertEq(rewards, 200 * WAD);
    }

    // ===== Fuzz Tests =====

    function testFuzz_ComputeRewardsNeverReverts(
        uint128 balance,
        uint128 debt,
        uint128 accumulatedRewards
    ) public view {
        // This should never revert regardless of inputs
        // Using uint128 to avoid overflow in balance * accumulatedRewards
        staking.exposed_computeRewards(balance, debt, accumulatedRewards);
    }

    function testFuzz_ComputeRewardsReturnsZeroWhenDebtHigher(
        uint128 balance,
        uint128 accumulatedRewards
    ) public view {
        vm.assume(balance > 0);
        vm.assume(accumulatedRewards > 0);

        uint256 accRewards = uint256(balance) * uint256(accumulatedRewards) / WAD;
        vm.assume(accRewards < type(uint128).max);

        uint256 debt = accRewards + 1; // Set debt higher than accRewards

        uint256 rewards = staking.exposed_computeRewards(balance, debt, accumulatedRewards);

        assertEq(rewards, 0);
    }

    function testFuzz_ComputeRewardsCorrectCalculation(
        uint64 balance,
        uint64 debt,
        uint64 accumulatedRewards
    ) public view {
        // Using smaller types to ensure no overflow
        uint256 bal = uint256(balance) * WAD;
        uint256 deb = uint256(debt) * WAD;
        uint256 acc = uint256(accumulatedRewards) * WAD;

        uint256 accRewards = bal * acc / WAD;
        uint256 expectedRewards = accRewards >= deb ? accRewards - deb : 0;

        uint256 actualRewards = staking.exposed_computeRewards(bal, deb, acc);

        assertEq(actualRewards, expectedRewards);
    }
}
