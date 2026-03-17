// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Crowdfunding {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable fundingGoal;
    uint256 public immutable deadline;
    uint256 public totalSupply;

    mapping(address => uint256) public contributions;

    event Contribution(address indexed contributor, uint256 amount);
    event CancelContribution(address indexed contributor, uint256 amount);
    event Withdrawal(address indexed beneficiary, uint256 amount);

    constructor(address token_, address beneficiary_, uint256 fundingGoal_, uint256 deadline_) {
        require(deadline_ > block.timestamp, "Deadline must be in the future");
        require(token_ != address(0), "Token address cannot be 0");
        require(beneficiary_ != address(0), "Beneficiary address cannot be 0");
        require(fundingGoal_ > 0 , "Funding goal must be greater than 0");
     token = IERC20(token_);
     beneficiary = beneficiary_;
     fundingGoal = fundingGoal_;
     deadline = deadline_;
    }

    /*
     * @notice a contribution can be made if the deadline is not reached.
     * @param amount the amount of tokens to contribute.
     */
    function contribute(uint256 amount) external {
      require(block.timestamp <= deadline , "Contribution period over");
      token.safeTransferFrom(msg.sender,address(this),amount);
      contributions[msg.sender] += amount;
      totalSupply += amount;
      emit Contribution(msg.sender,amount);
    }

    /*
     * @notice a contribution can be cancelled if the goal is not reached. Returns the tokens to the contributor.
     */ 
    function cancelContribution() external {
        require(token.balanceOf(address(this)) < fundingGoal,"Cannot cancel after goal reached") ;
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0 , "no contributions ");
        token.safeTransfer(msg.sender,contributed);

        contributions[msg.sender] = 0;
        totalSupply -= contributed;
        emit CancelContribution(msg.sender , contributed);
    }

    /*
     * @notice the beneficiary can withdraw the funds if the goal is reached.
     */
    function withdraw() external {
        require(msg.sender == beneficiary , "Only beneficiary can withdraw");
        require(token.balanceOf(address(this)) >= fundingGoal , "Funding goal not reached");
        require(block.timestamp > deadline , "Funding period not over");
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(beneficiary,amount);
        totalSupply = 0;
        emit Withdrawal(beneficiary,amount);
    }
}


