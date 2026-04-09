// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// A staking contract works by having a accumulatedRewardsPerDepositToken
// increase monotonically. The earlier someone deposits, the greater their
// accumulated rewards. The later someone deposits, the more the debt will
// cancel out the rewards. But accumulatedRewardsPerDepositToken is the same
// for each user. The difference in rewards is accomplished via debt.

// Important assumptions:
// 1. Tokens are 18 decimals and behave normally
// 2. Deployer should initialize with deposits already present, otherwise
//    someone can deposit 1 wei and allow the rewards to accumulate very fast
contract SlimStake is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant WAD = 1e18;

    // both tokens must be 10**18
    // must not revert on zero transfers
    IERC20 public depositToken;
    IERC20 public rewardToken;
   

 error InsufficientBalance();

    // in actual token value. So 0.5e18 means 0.5e18 reward token per deposited token per second
    // we want to distribute 1 reward token per day (1e18) per deposited token
    // so the default value is 1e18 / 86400 = 11_574_074_074_074
    uint256 public rewardPerDepositTokenPerSecond = 11_574_074_074_074;
    
    // NOTE: this is scaled up by 1e18 (WAD). Otherwise, decimal portions of the token would be
    // truncated. For example, if the reward rate is 1 wei per 1 deposit per second, and 10 second pass
    // the accumulated reward would be 10 wei. Since this is "per deposited token" however, we would
    // end up with 10 wei / deposits which would likely be zero. So we need to store the "scaled up"
    // version, then multiply or divide by WAD as needed when using this variable
    uint256 public accumulatedRewardsPerDepositTokenWAD = 0;
    uint40 public lastUpdateTime = uint40(block.timestamp);
    uint256 public totalDeposits;

    // balance is the actual amount of deposit tokens deposited in wei. It is not scaled.
    // debt is the actual amount of reward tokens in that should be subtracted from rewards
    // invariant: on fresh deposits/withdraw, debt * accumulatedRwardsPerDepositTokenWAD / WAD == balance
    // once you deposit, the rewards that you are owed on your deposit exactly equals your debt so you
    // don't get rewards until you let time pass and the reward per token increases in value
    struct DepositInfo {
        uint256 debt;
        uint256 balance;
    }

    mapping(address staker => DepositInfo) public deposits;

    event Deposit(address indexed staker, uint256 amount);
    event Withdraw(address indexed staker, uint256 amount);
    event SetRewardRate(uint256 time, uint256 rate);

constructor (IERC20 _depositToken, IERC20 _rewardToken) {
   require(_depositToken != _rewardToken , "deposit and reward tokens must be different");
    depositToken = _depositToken;
    rewardToken = _rewardToken;
}

    function setRewardRate(uint256 rate) external onlyOwner {
       _updatePool(); 
    rewardPerDepositTokenPerSecond = rate;
    emit SetRewardRate(block.timestamp,rate);
    }

    /**
     * @notice deposit token to earn rewards
     * @param amount amount to deposit
     * @dev first compute the amount of rewards earned so far, then transfer it to the user
     * @dev then transfer in the deposit from the user
     * @dev finally, set their balance to the correct amount
     * @dev the user's debt should be such that if they withdraw right away
     * @dev they will not get any rewards
     */
    function deposit(uint256 amount) external nonReentrant {
      _updatePool();

      DepositInfo storage user = deposits[msg.sender];

      uint256 rewards = _computeRewards(user.balance, user.debt , accumulatedRewardsPerDepositTokenWAD);

      if(rewards > 0 ) {
        _transferRewards(msg.sender,rewards);
      }
      if(amount > 0 ) {
        depositToken.safeTransferFrom(msg.sender,address(this),amount);
        user.balance += amount;
        totalDeposits += amount;
      }
      user.debt = (user.balance * accumulatedRewardsPerDepositTokenWAD) / WAD;
      emit Deposit(msg.sender,amount);

    }

    /**
     * @notice enables staker to withdraw their stake.
     * @dev first compute rewards earned so far, then transfer it to the user
     * @dev update balance and debt
     * @dev if amount withdrawn is greater than balance
     */ 
    function withdraw(uint256 amount) external nonReentrant {
    _updatePool();

     DepositInfo storage user = deposits[msg.sender];
     require(amount <= user.balance, "Amount can't be exceed from ");
     uint256 reward = _computeRewards(user.balance,user.debt,accumulatedRewardsPerDepositTokenWAD);

     if(reward > 0 ){
      _transferRewards(msg.sender,reward);
     }
     
     if(amount > 0 ){
      user.balance -= amount;
      totalDeposits -= amount;
     }
   depositToken.safeTransfer(msg.sender,amount);
   user.debt = (user.balance * accumulatedRewardsPerDepositTokenWAD) / WAD;
   emit Withdraw(msg.sender,amount);




    }

    /**
     * @notice return pending rewards for the account
     * @param account account to check
     */
    function viewRewards(address account) external view returns (uint256) {
      DepositInfo storage user = deposits[msg.sender];

    uint256 newAcc = accumulatedRewardsPerDepositTokenWAD + _increaseInAccumulatedRewardsPerTokenSinceLastUpdate();

      return _computeRewards(user.balance,user.debt,newAcc);
    }

    /**
     * @notice return the amount of stake the user has earned so far
     * @param balance the amount of deposit token the user currently has
     * @param debt a cancellation factor to ensure that new deposits don't earn stake on the same block
     * @dev be sure to compute rewards before updating their balance during deposit/withdraw!
     * @dev this function must always return zero on the same block after a deposit or withdraw
     * @dev this function must never revert28
     */
    function _computeRewards(uint256 balance, uint256 debt, uint256 _accumulatedRewardsPerDepositTokenWAD) internal pure returns (uint256) {
    // balance * accRPS - debt
    if(balance == 0) return 0 ;
    uint256 accumulated = (balance * _accumulatedRewardsPerDepositTokenWAD) / WAD;
    if(accumulated <= debt) return 0;
    return accumulated - debt;
    }

    /**
     * @notice this function must never revert. If the transfer amount is higher 
     *         than the reward balance, then send the remaining reward balance.
     * @param receiver address of recipient
     * @param amount rewards to send
     * @dev this means that the reward token must not revert on transfer value = 0
     * @dev this function must never revert
     */
    function _transferRewards(address receiver, uint256 amount) internal {
     uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
     if(amount > rewardTokenBalance){
          amount = rewardTokenBalance;
     } 
  if(amount > 0 ){
 rewardToken.safeTransfer(receiver, amount);
  }
   

    }

    /**
     * @notice updates accumulatedRewardsPerDepositToken
     * @dev must never revert
     * @dev updates `lastUpdateTime` to the current time
     */
    function _updatePool() internal {
       uint256 increase = _increaseInAccumulatedRewardsPerTokenSinceLastUpdate();
       accumulatedRewardsPerDepositTokenWAD += increase;
       lastUpdateTime = uint40(block.timestamp);
    }

    /**
     * compute the amount of rewards accumulated since last update as rewardPerToken * deltaTime / totalDeposits
     */
    function _increaseInAccumulatedRewardsPerTokenSinceLastUpdate() internal view returns (uint256) {
     if(totalDeposits == 0 ) return 0;
    
    uint256 deltaTime = block.timestamp - lastUpdateTime;
    uint256 totalReward = rewardPerDepositTokenPerSecond * deltaTime;
    uint256 increase = (totalReward * WAD) / totalDeposits;
    return increase;
    }
}
