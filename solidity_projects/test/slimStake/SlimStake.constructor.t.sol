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

contract SlimStakeConstructorTest is Test {
    MockERC20 public depositToken;
    MockERC20 public rewardToken;

    function setUp() public {
        depositToken = new MockERC20("Deposit Token", "DEP");
        rewardToken = new MockERC20("Reward Token", "REW");
    }

    function test_ConstructorSetsDepositToken() public {
        SlimStake staking = new SlimStake(depositToken, rewardToken);

        assertEq(address(staking.depositToken()), address(depositToken));
    }

    function test_ConstructorSetsRewardToken() public {
        SlimStake staking = new SlimStake(depositToken, rewardToken);

        assertEq(address(staking.rewardToken()), address(rewardToken));
    }

    function test_ConstructorSetsBothTokensCorrectly() public {
        SlimStake staking = new SlimStake(depositToken, rewardToken);

        assertEq(address(staking.depositToken()), address(depositToken));
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertTrue(address(staking.depositToken()) != address(staking.rewardToken()));
    }

    function test_ConstructorRevertsWhenTokensAreSame() public {
        vm.expectRevert("deposit and reward tokens must be different");
        new SlimStake(depositToken, depositToken);
    }

    function test_ConstructorRevertsWhenRewardTokenSameAsDeposit() public {
        vm.expectRevert("deposit and reward tokens must be different");
        new SlimStake(rewardToken, rewardToken);
    }
}
