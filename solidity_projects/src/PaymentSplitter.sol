// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Splitter {

    using SafeERC20 for IERC20;

    IERC20 internal immutable token;

    error InsufficientBalance();
    error InsufficientApproval();
    error ArrayLengthMismatch();

    function split(IERC20 token, address[] calldata recipients, uint256[] calldata amounts) external {
        require(address(token) != address(0), "ZERO_ADDRESS");
        if(recipients.length != amounts.length) revert ArrayLengthMismatch();
        uint256 allowed = token.allowance(msg.sender,address(this));
        uint256 ownerBalance = token.balanceOf(msg.sender);
        uint256 totalAmountSplitted;
        for(uint256 i = 0 ; i < recipients.length ; i++){
            require(recipients[i] != address(0), "ZERO_ADDRESS");
            totalAmountSplitted = totalAmountSplitted + amounts[i];
        }
        if(allowed < totalAmountSplitted){
            revert InsufficientApproval();
        }
        if(ownerBalance < totalAmountSplitted){
            revert InsufficientBalance();
        }
        for(uint256 i = 0 ; i < recipients.length ; i++){
            token.safeTransferFrom(msg.sender,recipients[i],amounts[i]);
        }
    }
}
