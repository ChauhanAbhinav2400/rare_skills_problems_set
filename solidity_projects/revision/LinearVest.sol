// SPDX-License-Identifier : MIT 
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinearVest {
using SafeERC20 for IERC20;
struct Vest {
    address token;
    uint40 startTime;
    address recipient;
    uint40 duration;
    uint256 amount;
    uint256 withdrawn;
}

event VestCreated(
    address indexed sender,
    address indexed recipient,
    address token,
    uint256 amount,
    uint256 startTime,
    uint256 duration
);

event VestWithdrawn(
    address indexed recipient,
    bytes32 indexed vestId,
    address token,
    uint256 amount,
    uint256 timestamp
)   ;

mapping(bytes32 => Vest) public vests;
bytes32[] public vestIds;


function createVest(
    IERC20 token, 
    address recipient,
    uint256 amount, 
    uint40 startTime,
    uint40 duration,
    uint256 salt
) external {
    require(address(token) != address(0));
    require(recipient != address(0));
    require(amount > 0);
    require(startTime >= block.timestamp);
    require(duration > 0);
    bytes32 vestId = computeVestId(IERC20(token),recipient,amount,startTime,duration,salt);
    require(vests[vestId].amount == 0, "Vest already exists");
    uint256 balanceBefore = token.balanceOf(address(this));
    token.safeTransferFrom(msg.sender, address(this), amount);
    uint256 balanceAfter = token.balanceOf(address(this));
    require(balanceAfter - balanceBefore == amount , "Fee on transfer not allowed");
    vests[vestId] = Vest({
        token:address(token),
        recipient:recipient,
        startTime:startTime,
        duration:duration,
        amount:amount,
        withdrawn:0
    });
    vestIds.push(vestId);
    emit VestCreated(msg.sender , recipient, address(token), amount, startTime, duration);
}


function withdrawVest(bytes32 vestId , uint256 amount) external {
    Vest storage vest = vests[vestId];
    require(vest.amount > 0 , "Vest does not exist");
    require(vest.recipient == msg.sender, "Not recipient");
    require(block.timestamp >= vest.startTime , "Vest not started");

    uint256 elasped = block.timestamp - vest.startTime;
    if(elasped > vest.duration) {
        elasped = vest.duration;
    }

    uint256 vestedAmount = (vest.amount * elasped) / vest.duration;
    uint256 withdrawble = vestedAmount - vest.withdrawn;
    require(withdrawble > 0, "Nothing to withdraw");

    uint256 amountToWithdraw = amount > withdrawble ? withdrawble : amount;
    vest.withdrawn += amountToWithdraw;
    IERC20(vest.token).safeTransfer(vest.recipient , amountToWithdraw);
    emit VestWithdrawn(vest.recipient, vestId, vest.token, amountToWithdraw, block.timestamp);  
}



function computeVestId(
    IERC20 token, 
    address recipient,
    uint256 amount, 
    uint40 startTime,
    uint40 duration,
    uint256 salt
) public pure returns (bytes32) {
    bytes32 vestId = keccak256(abi.encode(token,recipient,amount,startTime,duration,salt));
    return vestId;
}

}
