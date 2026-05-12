

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract Farm {

using SafeERC20 for IERC20;

error ZeroAmount();
error InvalidAddress();
error InsufficientBalance();

event Deposit(address indexed user , uint256 amount );
event Withdraw(address indexed user , uint256 amount);

IERC20 public lpToken;
IERC20 public rewardToken;

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
    rewardToken = IERC20(_rewardToken);
}


function deposit(uint256 amount) external {
    
    if (amount == 0 ) revert ZeroAmount();
    _updatePool();
    UserInfo memory user = userInfo[msg.sender];
    uint256 pendingRewards;
    if(user.amount > 0 ){
     pendingRewards = ((user.amount * accRewardPerShare ) / WAD) - user.rewardDebt;
     rewardToken.mint(msg.sender,pendingRewards);
    } 
    lpToken.safeTransferFrom(msg.sender,address(this),amount);
    user.amount += amount;
    totalStaked += amount;
    lastRewardTime = uint40(block.timestamp);

   emit Deposit(msg.sender, amount);

}


function withdraw(uint256 amount) external {
    if (amount <= 0 ) revert ZeroAmount();
    if (balance[msg.sender] < amount) revert InsufficientBalance();
   
    totalStaked -= amount;
    lpToken.safeTransfer(msg.sender , amount);
    emit Withdraw(msg.sender, amount);
}

function _updatePool() internal {
    if(block.timestamp <= lastRewardTime) {
        return;
    }
    if(totalStaked == 0 ){
        lastRewardTime = uint40(block.timestamp);
        return;
    }

    uint256 timeElasped = block.timestamp - lastRewardTime;
    uint256 reward = timeElasped * rewardPerSecond;
    accRewardPerShare += reward * WAD / totalStaked;
    lastRewardTime = uint40(block.timestamp);
}


}