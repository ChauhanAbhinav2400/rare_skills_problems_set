pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Splitter {   

using SafeERC20 for IERC20;

error InsufficientBalance();
    error InsufficientApproval();
    error ArrayLengthMismatch();
    
function split ( IERC20 token , address[] calldata recipients , uint256[] calldata amounts) external {
    require(address(token) != address(0));
    if(recipients.length != amounts.length) revert ArrayLengthMismatch();
    uint256 totalAmountSplitted;
    uint256 allowed = token.allowance(msg.sender , address(this));
    for(uint256 i = 0 ; i < recipients.length; i++){
        totalAmountSplitted = totalAmountSplitted + amounts[i];
    }

    if(totalAmountSplitted > allowed) {
        revert InsufficientApproval();
    }

    if(totalAmountSplitted > token.balanceOf(msg.sender)) revert InsufficientBalance();

    for(uint256 i = 0 ; i < recipients.length ; i++) {
        token.safeTransferFrom(msg.sender , recipients[i] , amounts[i]);
    }

}

}