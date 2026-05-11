

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

uint256 public totalStaked;
mapping(address => uint256 ) public balance;
mapping (address => uint40) public lastUpdatedTime;
mapping (address => uint256 ) public pendingRewards;

constructor(address _lpToken , address _rewardToken) {
    if(_lpToken == address(0) || _rewardToken == address(0)) revert InvalidAddress();
    lpToken = IERC20(_lpToken);
    rewardToken = IERC20(_rewardToken);
}


function deposit(uint256 amount) external {
if (amount <= 0 ) revert ZeroAmount();
lpToken.safeTransferFrom(msg.sender , address(this), amount);
uint256 timeElasped = block.timestamp - lastUpdatedTime[msg.sender];
if(timeElasped > 0 && balance[msg.sender] > 0){
    uint256 rewards = balance[msg.sender] * timeElasped;
    pendingRewards[msg.sender] += rewards;
}
balance[msg.sender] += amount;
totalStaked += amount;
lastUpdatedTime[msg.sender] = uint40(block.timestamp);
emit Deposit(msg.sender, amount);

}


function withdraw(uint256 amount) external {
    if (amount <= 0 ) revert ZeroAmount();
    if (balance[msg.sender] < amount) revert InsufficientBalance();
    uint256 timeElasped = block.timestamp - lastUpdatedTime[msg.sender];
    if(timeElasped > 0 && balance[msg.sender] > 0){
    uint256 rewards = balance[msg.sender] * timeElasped;
    pendingRewards[msg.sender] += rewards;
    }
    balance[msg.sender] -= amount;
    totalStaked -= amount;
    lastUpdatedTime[msg.sender] = uint40(block.timestamp);
    lpToken.safeTransfer(msg.sender , amount);
    emit Withdraw(msg.sender, amount);
}


}