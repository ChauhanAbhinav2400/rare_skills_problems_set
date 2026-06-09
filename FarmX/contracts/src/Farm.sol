
// SPDX-License-Identifier : MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RewardToken} from "./RewardToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Farm is ReentrancyGuard {

using SafeERC20 for IERC20;

error ZeroAmount();
error InvalidAddress();
error InsufficientBalance();

event Deposit(address indexed user , uint256 amount );
event Withdraw(address indexed user , uint256 amount);

IERC20 public lpToken;
RewardToken public rewardToken;

struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
}

uint256 public totalStaked;
uint256 public rewardPerSecond;
uint40 public lastRewardTime;
uint256 public accRewardPerShare; 
uint256 private constant WAD = 1e18;
mapping(address => UserInfo) public userInfo;

constructor(address _lpToken , address _rewardToken) {
    if(_lpToken == address(0) || _rewardToken == address(0)) revert InvalidAddress();
    lpToken = IERC20(_lpToken);
    rewardToken = RewardToken(_rewardToken);
    lastRewardTime = uint40(block.timestamp);
    rewardPerSecond = 1e18; 
}


function deposit(uint256 amount) external nonReentrant {

    _updatePool();
    UserInfo storage user = userInfo[msg.sender];
    uint256 pendingRewards;
    if(user.amount > 0 ){
        if(((user.amount * accRewardPerShare) / WAD) < user.rewardDebt) {
            pendingRewards = 0;
        } else {
            pendingRewards = _pendingRewards(user, accRewardPerShare);
        }
     rewardToken.mint(msg.sender,pendingRewards);
    } 
    lpToken.safeTransferFrom(msg.sender,address(this),amount);
    user.amount += amount;
    totalStaked += amount;
    user.rewardDebt = (user.amount * accRewardPerShare) / WAD;

   emit Deposit(msg.sender, amount);

}




function withdraw(uint256 amount) external nonReentrant {
    if (amount == 0 ) revert ZeroAmount();
     _updatePool();
     UserInfo storage user = userInfo[msg.sender];
     if(user.amount < amount) revert InsufficientBalance();
      uint256 pendingRewards;
      if(((user.amount * accRewardPerShare) / WAD) < user.rewardDebt) {
            pendingRewards = 0;
        } else {
            pendingRewards = _pendingRewards(user , accRewardPerShare);
        }
     rewardToken.mint(msg.sender,pendingRewards);
     user.amount -= amount;
     totalStaked -= amount;
     lpToken.safeTransfer(msg.sender,amount);
     user.rewardDebt = (user.amount * accRewardPerShare) / WAD;
    emit Withdraw(msg.sender, amount);
}


function _pendingRewards(UserInfo memory _user , uint256 accRPS) internal view returns( uint256 ) {
    return  ((_user.amount * accRPS) / WAD) - _user.rewardDebt;     
}

function viewRewards(address _user) external view returns(uint256) {
     
         UserInfo memory user = userInfo[_user];
         uint256 accumulatedRewardPerShare = accRewardPerShare;
         if(block.timestamp > lastRewardTime && totalStaked != 0){
           accumulatedRewardPerShare +=  increaseInRewardPerShare();
         }
    return _pendingRewards(user, accumulatedRewardPerShare);
}

function userStakedAmount(address _user) external view returns(uint256) {
    return userInfo[_user].amount;
}

function tvl() external view returns(uint256 ){
    return totalStaked;
}

function increaseInRewardPerShare() internal view returns(uint256) {
    uint256 timeElapsed = block.timestamp - lastRewardTime;
    uint256 reward = timeElapsed * rewardPerSecond;
    return (reward * WAD) / totalStaked;
}

function _updatePool() internal {
    if(block.timestamp <= lastRewardTime) {
        return;
    }
    if(totalStaked == 0 ){
        lastRewardTime = uint40(block.timestamp);
        return;
    }
    accRewardPerShare += increaseInRewardPerShare();
    lastRewardTime = uint40(block.timestamp);
}



}