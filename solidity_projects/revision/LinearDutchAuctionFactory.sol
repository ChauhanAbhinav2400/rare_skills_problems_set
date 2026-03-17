pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinearDutchAuctionFactory {
using SafeERC20 for IERC20;

event AuctionCreated(address indexed auctionAddress , address indexed seller , address indexed token , uint256 amount , uint256 startPrice , uint256 duration , uint256 startTime);

function createAuction(
    address token,
    uint256 amount,
    uint256 startPrice,
    uint256 duration,
    uint256 startTime,
    address seller
) external returns(address) {
    require(address(_token) != address(0), "ZERO_ADDRESS");
        require(startPrice > 0 , "");
        require(startTime >= block.timestamp,"");
        require(duration > 0 ,"");
        require(seller != address(0), "");
     auction = address(
        new LinearDutchAuction(
            token,
            startPrice,
            duration,
            startTime,
            seller
        )
     )

     IERC20(token).safeTransferFrom(seller , auction , amount);
     emit AuctionCreated(auction , seller , token , amount , startPrice , duration , startTime);
     return auction;
}

}



contract LinearDutchAuction {
using SafeERC20 for IERC20;
address public immutable token;
address public immutable seller;
uint256 public immutable startPrice;
uint256 public immutable duration;
uint256 public immutable startTime;

bool public sold;

constructor(
    address token_,
    uint256 startPrice_,
    uint256 duration_,
    uint256 startTime_,
    address seller_
) {
    token = token_;
    seller = seller_;
    startPrice = startPrice_;
    duration = duration_;
    startTime = startTime_;


}

function currentPrice() public view returns(uint256) {
if(block.timestamp < startTime) {
    revert ("Auction not started");
}

uint256 elasped = block.timestamp - startTime;
if(elasped >= duration) {
    return 0;
}
if(sold){
    return 0;
}

uint256 priceDrop = (startPrice * elasped) / duration;
return startPrice - priceDrop; 


}

receive() external payable {
require(block.timestamp >= startTime , "Auction not started");
require(!sold , "Token already sold");
uint256 price = currentPrice();
require(msg.value >= price , "Not enough Ether sent");
sold = true;

IERC20(token).safeTransfer(msg.sender , IERC20(token).balanceOf(address(this)));
(bool success,) = seller.call{value:msg.value}("");
require(success , "Failed to send Ether to seller");

if(msg.value > price) {
    unchecked{
        uint256 refund = msg.value - price;
        (bool refundSuccess, ) = payable(msg.sender).call{value:refund}("");
        require(refundSuccess , "Failed to refund excess Ether");
    }
}

}

}